(import halo2)
(import path)
(import cipher)
(import uri)
(import ./session)
(import ./csrf)
(import ./form)
(import ./multipart)
(import ./helpers :prefix "")
(import janet-html :as html)


(def- *routes* @[])
(def- *before-fns* @[])
(def- *after-fns* @[])
(def- *osprey-after-fns* @[])
(var- *session-secret* nil)
(var- *not-found-fn* nil)
(var- *layout* @{})


(defn- slash-suffix [p]
  (if (keyword? (last p))
    (put p (dec (length p)) :slash-param)
    p))


(defn- wildcard-params [patt uri]
  (when (and patt uri)
    (let [p (->> (string/split "*" patt)
                 (interpose :param)
                 (filter any?)
                 (slash-suffix)
                 (freeze))

          route-peg ~{:param (<- (any (+ :w (set "%$-_.+!*'(),"))))
                      :slash-param (<- (any (+ :w (set "%$-_.+!*'(),/"))))
                      :main (* ,;p)}]

      (if (= patt uri)
        @[""]
        (or (peg/match route-peg uri)
            @[])))))


(defn- route-param? [val]
  (string/has-prefix? ":" val))


(defn- route-param [val]
  (if (route-param? val)
    val
    (string ":" val)))


(defn- route-params [app-url path]
  (when (and app-url path)
    (let [app-parts (string/split "/" app-url)
          req-parts (string/split "/" path)]
      (as-> (interleave app-parts req-parts) ?
            (partition 2 ?)
            (filter (fn [[x]] (route-param? x)) ?)
            (map (fn [[x y]] @[(keyword (drop 1 x)) y]) ?)
            (mapcat identity ?)
            (table ;?)))))


(defn- part? [[s1 s2]]
  (or (= s1 s2)
      (string/find ":" s1)))


(def- parts '(some (* "/" '(any (+ :a :d (set ":%$-_.+!*'(),"))))))


(defn- route? [request app-route]
  (let [[route-method route-url] app-route
        {:path uri :method method} request]

    # check methods match first
    (and (= (string/ascii-lower method)
            (string/ascii-lower route-method))

         # check that the url isn't an exact match
         (or (= route-url uri)

             # check for urls with params
             (let [uri-parts (peg/match parts uri)
                   route-parts (peg/match parts route-url)]

               # 1. same length
               # 2. the route definition has a semicolon in it
               # 3. the length of the parts are equal after
               #    accounting for params
               (and (= (length route-parts) (length uri-parts))
                    (string/find ":" route-url)
                    (= (length route-parts)
                       (as-> (interleave route-parts uri-parts) ?
                             (partition 2 ?)
                             (filter part? ?)
                             (length ?)))))

             # wildcard params (still a work in progress)
             (and (string/find "*" route-url)
                  (let [idx (string/find "*" route-url)
                        sub (string/slice route-url 0 idx)]
                    (string/has-prefix? sub uri)))))))


(defn- find-route [routes request]
  (or (find (partial route? request) routes)
      @[]))


(defn- run-before-fns [request]
  (each [patt f] *before-fns*
    (when (any? (wildcard-params patt (request :uri)))
      (f request))))


(defn- run-after-fns [response request after-fns]
  (var res response)

  (each [patt f] after-fns
    (when (any? (wildcard-params patt (request :uri)))
      (set res (f res request))))

  res)


(defn halt
  `
  halts all processing and returns immediately with the given response dictionary

  Example:

  (halt {:status 500
         :body "internal server error"
         :headers {"Content-Type" "text/plain"}})
  `
  [response]
  (return :halt response))


(defn- parse-body [request]
  (cond
    (multipart/multipart? request)
    (multipart/params request)

    (form/form? request)
    (form/decode (get request :body))

    :else
    @{}))


(defn add-header
  `Deprecated.

   Use (header key value) instead.`
  [response key value]
  (let [val (get-in response [:headers key])]
    (if (indexed? val)
      (update-in response [:headers key] array/push value)
      (put-in response [:headers key] value))))

(defn header
  `
  Adds a header to the current response dyn

  If the value is an array it uses array/push to add to the value

  Returns the response dictionary

  Example:

  (before "*"
    (header "Content-Type" "application/json"))
  `
  [key value]
  (let [response (dyn :response)
        val (get-in response [:headers key])]
    (if (indexed? val)
      (update-in response [:headers key] array/push value)
      (put-in response [:headers key] value))))


(defn content-type
  `Sets the content-type of the current response

  Example:

  (before "*"
    (content-type "text/html"))`
  [ct]
  (header "Content-Type" ct))


(defn status
  `Sets the status of the current response

  Example:

  (before "*"
    (content-type "text/html"))`
  [s]
  (put (dyn :response) :status s))


(defn- response-table
  `Coerce any value into a response dictionary`
  [response]
  (if (dictionary? response)
      (merge (dyn :response) response)
      (put (dyn :response) :body response)))


(defn- not-found-response [response request f]
  (let [file (get response :file "")]
    (cond
      (halo2/file-exists? file)
      response

      (nil? f)
      (if *not-found-fn*
        (do
          # run user defined 404 function
          (status 404)
          (halt (response-table (*not-found-fn* request))))
        # otherwise return a basic not found plaintext 404
        (halt @{:status 404
                :body "not found"
                :headers @{"Content-Type" "text/plain"}}))

      :else
      response)))


(defn- redirect-response [response]
  (if (empty? (dyn :redirect))
    response
    (merge response (dyn :redirect))))


(defn- handler
  "Creates a handler function from routes. Returns nil when handler/route doesn't exist."
  [routes]
  (fn [request]
    (prompt
      :halt

      (let [request (merge request (uri/parse (request :uri)))
            route (find-route routes request)
            [method uri f] route
            wildcard (wildcard-params uri (request :uri))
            params (or (route-params uri (request :path)) {})
            params (merge params (map-keys keyword (get request :query {})))
            params (merge params (parse-body request))
            request (merge request {:params params
                                    :wildcard wildcard
                                    :text-body (request :body)
                                    :route-uri (get route 1)})]

        (with-dyns [:response @{:status 200
                                :headers @{"Content-Type" "text/plain"}}
                    :redirect @{}
                    :layout nil
                    :flashed? nil]

          # run all before-fns before request
          (run-before-fns request)

          # run handler fn
          (as-> (f request) ?
                # run all after-fns after request
                (run-after-fns ? request *after-fns*)
                # coerce response into table
                (response-table ?)
                # check for redirects
                (redirect-response ?)
                # check for 404s
                (not-found-response ? request f)
                # apply session bits to response table
                (run-after-fns ? request *osprey-after-fns*)))))))


(def app :public `
  Stops just short of sending http requests and responses over the server.
  Mostly useful for testing.

  Example:

  (import osprey :prefix "")

  (GET "/example" "example")

  (app {:uri "/example" :method "GET"})

  # =>

  @{:status 200 :body "example" :headers @{"Content-Type" "text/plain"}}
  `
  (handler *routes*))


(defn render
  `
  Re-renders a given GET route with a new request that you define.

  Good for re-rendering forms on errors.

  Example:

  (use osprey)

  (before "*"
          (content-type "text/html"))

  (GET "/" [:h1 "home"])

  (GET "/form"
       [:main
        (when (request :errors)
          [:div (request :errors)])

        (form {:action "/form"}
          [:input {:type "text" :name "name"}]
          [:input {:type "submit" :value "submit"}])])

  (POST "/form"
        (if (empty? (get params :name ""))
          (render "/form" (merge request {:errors "name is blank"}))
          (redirect "/")))
  `
  [request url &opt req]
  (app (merge (or req request) {:uri url :method "GET"})))


(defn view
  `
  Outputs the return value for a given route without re-running before macros

  Example:

  (use osprey)

  (before "*" (print "before"))

  (GET "/im" "i'm")

  (GET "/home" (string (view "/im") " home")) # outputs "i'm home" and doesn't print "before"
  `
  [request uri]
  (let [route (-> (filter (fn [[method uri*]] (and (= method :get) (= uri uri*))) *routes*)
                  (first))
        f (last route)]
    (f request)))


(defn- add-route [method uri f]
  (array/push *routes* [method uri f]))


(defn- route-url [string-route &opt params]
  (default params @{})
  (var mut-string-route string-route)
  (loop [[k v] :in (pairs params)]
    (set mut-string-route (string/replace (route-param k) (string v) mut-string-route))
    (when (and (= k :*)
               (indexed? v))
      (loop [wc* :in v]
        (set mut-string-route (string/replace "*" (string wc*) mut-string-route)))))
  mut-string-route)


(defn form
  `
  Form helper that outputs a form with a hidden input with the csrf-token defined
  and sets the method to POST

  Note: this only works inside of GET macros

  Example:

  (enable :sessions)
  (enable :csrf-tokens)

  (GET "/"
    (form {:action "/"}
      [:input {:type "text"}]))

  # =>

  [:form {:action "/" :method "post"}
    [:input {:type "hidden" :name "__csrf-token" :value "<csrf-token-value>"}]
    [:input {:type "text"}]]
  `
  [csrf-token attrs & body]
  [:form (merge {:method "post"} attrs)
   (when csrf-token
     [:input {:type "hidden" :name "__csrf-token" :value csrf-token}])
   ;body])


(defmacro GET
  `Creates a GET route

  Example:

  (GET "/" "home")
  `
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :get
          ,$uri
          (fn [request]
            (let [{:params params
                   :body body
                   :headers headers} request
                  render (partial render request)
                  form (partial form (get request :csrf-token))
                  view (partial view request)]
              (do ,;*osprey-args*)))))))


(defmacro POST
  `Creates a POST route

  Example:

  (POST "/" (redirect "/elsewhere"))`
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :post
          ,$uri
          (fn [request]
            (let [{:params params
                   :body body
                   :headers headers} request
                  render (partial render request)
                  form (partial form (get request :csrf-token))
                  view (partial view request)]
              (do ,;*osprey-args*)))))))


(defmacro PUT
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :put
          ,$uri
          (fn [request]
            (let [{:params params
                   :body body
                   :headers headers} request
                  render (partial render request)]
              (do ,;*osprey-args*)))))))


(defmacro PATCH
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :patch
          ,$uri
          (fn [request]
            (let [{:params params
                   :body body
                   :headers headers} request
                  render (partial render request)]
              (do ,;*osprey-args*)))))))


(defmacro DELETE
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :delete
          ,$uri
          (fn [request]
            (let [{:params params
                   :body body
                   :headers headers} request
                  render (partial render request)]
              (do ,;*osprey-args*)))))))


(defn- add-before [uri args]
  (array/push *before-fns* [uri args]))


(defmacro before
  `Runs a bit of code before all routes defined by uri

  Examples:

  (before "*"
          (print "this code will run before all routes"))

  (before "/todos/*"
          (print "this code will run before all routes starting with /todos/"))
  `
  [& *osprey-args*]
  (var uri "*")
  (var *osprey-args* *osprey-args*)

  (when (keyword? (first *osprey-args*))
    (set uri (first *osprey-args*))
    (set *osprey-args* (drop 1 *osprey-args*)))

  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-before ,$uri
          (fn [request]
            (let [{:headers headers
                   :body body
                   :params params
                   :method method} request
                  form (partial form (get request :csrf-token))
                  response (dyn :response)]
              (do ,;*osprey-args*)))))))


(defn- add-after [uri args]
  (array/push *after-fns* [uri args]))


(defn- add-osprey-after [uri args]
  (array/push *osprey-after-fns* [uri args]))


(defmacro after
  `Deprecated.

  Try not to use this, it has weird side effects when combined
  with things like (enable), (not-found), and (layout)`
  [& *osprey-args*]
  (var uri "*")
  (var *osprey-args* *osprey-args*)

  (when (keyword? (first *osprey-args*))
    (set uri (first *osprey-args*))
    (set *osprey-args* (drop 1 *osprey-args*)))

  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-after ,$uri
          (fn [response &opt request]
            (let [{:headers headers
                   :body body
                   :params params
                   :method method} request
                  form (partial form (get request :csrf-token))]
              (do ,;*osprey-args*)))))))


(defmacro- after-last [& *osprey-args*]
  (var uri "*")
  (var *osprey-args* *osprey-args*)

  (when (keyword? (first *osprey-args*))
    (set uri (first *osprey-args*))
    (set *osprey-args* (drop 1 *osprey-args*)))

  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-osprey-after ,$uri
          (fn [response request]
            (let [{:headers headers
                   :body body
                   :params params} request]
              (do ,;*osprey-args*)))))))


(defn- set-not-found [args]
  (set *not-found-fn* args))


(defmacro not-found
  `
  Runs a bit of code when a route or static file can't be found

  Example:

  (not-found
    (status :404)
    (content-type "text/html")

    [:h1 "not found"])
  `
  [& *osprey-body*]
  ~(,set-not-found (fn [request]
                     (let [{:headers headers
                            :params params
                            :method method
                            :body body} request]
                       (do ,;*osprey-body*)))))


(defn use-layout
  `Sets which layout to use if using named layouts`
  [name]
  (setdyn :layout name))


(defmacro layout
  `
  Creates a layout which will wrap all janet-html responses.

  Also sets the content-type to "text/html"

  Create multiple layouts by passing a keyword as the first argument
  and calling use-layout.
  `
  [& *osprey-args*]
  (var name :default)
  (var *args* *osprey-args*)

  (when (keyword? (first *osprey-args*))
    (set name (first *osprey-args*))
    (set *args* (drop 1 *osprey-args*)))

  (when (= name :default)
    (use-layout :default))

  (with-syms [$name]
    ~(let [,$name ,name]

      (after "*"
             (if (and (tuple? response)
                      (= (dyn :layout) ,$name))
                 (do
                    (content-type "text/html")
                    (html/encode ,;*args*))

                response)))))


(defn server
  `Start an http server listening on port 0 and localhost by default`
  [&opt port host]
  (default port 0)
  (default host "localhost")

  (halo2/server app port host))


# alias route-url to href
# for anchor tags
(def href :public
  `Helper for working with route urls.

  Example:

  (href "/todos/:id" {:id 1}) # => "/todos/1"`
  route-url)

(def action :public
  `Helper for working with form actions. Same as href.`
  route-url)


(defn redirect
  `Help for responding with a redirect response

  Examples:

  (redirect "/hello") => @{:status 302 :headers @{"Location" "/hello"}}

  # given a route that looks like this:
  (get "/todos/:id" [:div (string "todo " (params :id))])

  (redirect "/todos/:id" {:id 1}) => @{:status 302 :headers @{"Location" "/todos/1"}}`
  [str &opt params]
  (default params @{})
  (let [uri (route-url str params)]
    (setdyn :redirect @{:status 302
                        :headers @{"Location" uri}})))


(defn- enable-static-files [public-folder]
  (after "*"
         (if response
           response
           (let [public-folder (or public-folder "public")
                 path (request :path)
                 file-path (if (string/has-suffix? "/" path)
                             (string path "index.html")
                             path)]
             (put (dyn :response) :file (path/join public-folder file-path))))))


(defn- enable-sessions [options]
  (set *session-secret* (get options :secret (cipher/encryption-key)))

  (before "*"
          (let [o-session (session/decrypt *session-secret* request)]
            (set! session (get o-session :user))
            # flash messages
            (set! flash (get o-session :flash @{}))
            (setdyn :flashed? (not (empty? flash)))))

  (after-last "*"
              (let [response (if (dictionary? response)
                               response
                               (put (dyn :response) :body (string response)))]
                (as-> (session/encrypt *session-secret*
                                       {:user session
                                        :flash (if (dyn :flashed?) @{} flash)
                                        :flashed? (not (dyn :flashed?))
                                        :csrf-token (eval 'csrf-token)}) ?
                      (session/cookie ? options)
                      (add-header response "Set-Cookie" ?)))))


(defn- enable-csrf-tokens [&opt options]
  (default options {:skip []})

  (before "*"
          (when (find (partial = (request :route-uri)) (options :skip))
            (break))

          (let [session (session/decrypt *session-secret* request)]
            (when (= "post" (string/ascii-lower method))
              (unless (csrf/tokens-equal? (csrf/request-token headers params) (csrf/session-token session))
                (halt @{:status 403 :body "Invalid CSRF Token" :headers @{"Content-Type" "text/plain"}})))

            # set a new token
            (set! csrf-token (get session :csrf-token (csrf/token)))

            # mask the token for forms
            (put request :csrf-token (csrf/mask csrf-token)))))

(defn- enable-logging [&opt options]
  (def formats
    (or options
        (fn [start request response]
          (def {:uri uri
                :http-version version
                :method method
                :query-string qs} request)
          (def fulluri (if (and qs (pos? (length qs))) (string uri "?" qs) uri))
          (def elapsed (* 1000 (- (os/clock) start)))
          (def status (or (get response :status) 200))
          (printf "HTTP/%s %s %i %s elapsed %.3fms" version method status fulluri elapsed))))

  (before "*"
          (set! _start-clock (os/clock)))
  (after "*"
         (formats _start-clock request response)
         response))


(defn enable
  `Enable different middleware.

  Options are:

  - :static-files
  - :sessions
  - :csrf-tokens
  - :logging

  ## :static-files

  Serve static files from "public" directory.
  Pass in a string to change which directory they are served from.

  (enable :static-files)

  or

  (enable :static-files "static")

  ## :sessions

  Adds an encrypted session cookie to all responses, pass a dictionary to configure.

  Dictionary keys/values correspond to cookie keys/values, except for secret.

  The :secret key is for encrypting the session cookies and persisting that data between
  server restarts. If you don't pass it, when you restart the server, all existing
  session cookies will be invalid since there will be a new secret key.

  Default cookie headers look like this:

  Set-Cookie: session=<encrypted session data> SameSite=Lax; HttpOnly; Path=/

  All cookie options:

  :samesite <"Lax" or "Strict" or "None">
  :httponly <true or false>
  :path <any string>
  :secret <true or false>
  :domain <any string>
  :expires <any string>
  :max-age <any string>

  Example:

  (enable :sessions)

  or

  (enable :sessions {:secret (os/getenv "SECRET_KEY") :secure false :samesite "Strict"})

  ## :csrf-tokens

  Enables csrf tokens on forms. Requires a call to (enable :sessions) as well.

  Example:

  (enable :csrf-tokens {:skip ["/stripe-web-hooks"]})

  Pass a dictionary with :skip key to skip a set of routes, like:

  (enable :csrf-tokens)

  ## :logging

  Enables logging. Can pass a function as the argument to configure logging.

  See the amazing example put together by @pepe: https://github.com/swlkr/osprey/examples/logging.janet

  Example:

  (enable :logging)
  `
  [key &opt val]
  (case key
    :static-files
    (enable-static-files val)

    :sessions
    (enable-sessions val)

    :csrf-tokens
    (enable-csrf-tokens val)

    :logging
    (enable-logging val)))
