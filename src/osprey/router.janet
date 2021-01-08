(import halo2)
(import path)
(import cipher)
(import uri)
(import ./session)
(import ./csrf)
(import ./form)
(import ./multipart)
(import ./helpers :prefix "")

(def- *routes* @[])
(def- *before-fns* @[])
(def- *after-fns* @[])
(def- *osprey-after-fns* @[])
(var- *session-secret* nil)

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
  (let [app-parts (string/split "/" app-url)
        req-parts (string/split "/" path)]
    (as-> (interleave app-parts req-parts) ?
          (partition 2 ?)
          (filter (fn [[x]] (route-param? x)) ?)
          (map (fn [[x y]] @[(keyword (drop 1 x)) y]) ?)
          (mapcat identity ?)
          (table ;?))))


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


(defn- run-after-fns [response request]
  (var res response)

  (each [patt f] [;*after-fns* ;*osprey-after-fns*]
    (when (any? (wildcard-params patt (request :uri)))
      (set res (f res request))))

  res)


(defn halt [response]
  (return :halt response))


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
            params (route-params uri (request :path))
            params (merge params (map-keys keyword (get request :query {})))
            request (merge request {:params params
                                    :wildcard wildcard
                                    :text-body (request :body)
                                    :route-uri (get route 1)})]

        # run all before-fns before request
        (run-before-fns request)

        # run all after-fns after request
        (let [response (f request)
              response (run-after-fns response request)]

          (if (dictionary? response)
            response
            (ok text/plain (string response))))))))


(def app (handler *routes*))


(defn render [request url &opt req]
  (app (merge (or req request) {:uri url :method "GET"})))


(defn view [request uri]
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


(defn form [csrf-token attrs & body]
  [:form (merge {:method "post"} attrs)
   (when csrf-token
     [:input {:type "hidden" :name "__csrf-token" :value csrf-token}])
   ;body])


(defmacro GET
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


(defmacro before [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-before ,$uri
          (fn [request]
            (let [{:headers headers
                   :body body
                   :params params
                   :method method} request
                  form (partial form (get request :csrf-token))]
              (do ,;*osprey-args*)))))))


(defn- add-after [uri args]
  (array/push *after-fns* [uri args]))


(defn- add-osprey-after [uri args]
  (array/push *osprey-after-fns* [uri args]))


(defmacro after [uri & *osprey-args*]
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


(defmacro- after-last [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-osprey-after ,$uri
          (fn [response &opt request]
            (let [{:headers headers
                   :body body
                   :params params} request]
              (do ,;*osprey-args*)))))))


(defn server [&opt port host]
  (default port 0)
  (default host "localhost")

  (halo2/server app port host))


# alias route-url to href
# for anchor tags
(def href route-url)
(def action route-url)


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
    @{:status 302
      :headers @{"Location" uri}}))


(defn add-header [response key value]
  (let [val (get-in response [:headers key])]
    (if (indexed? val)
      (update-in response [:headers key] array/push value)
      (put-in response [:headers key] value))))


(defn- enable-static-files [public-folder]
  (after "*"
         (if response
           response
           (let [public-folder (or public-folder "public")
                 uri (request :uri)
                 file-path (if (string/has-suffix? "/" uri)
                             (string uri "index.html")
                             uri)]
             @{:file (path/join public-folder file-path)}))))


(defn- enable-sessions [options]
  (set *session-secret* (get options :secret (cipher/encryption-key)))

  (before "*"
          (let [o-session (session/decrypt *session-secret* request)]
            (set! session (get o-session :user))))

  (after-last "*"
              (let [response (if (dictionary? response)
                               response
                               (ok text/plain (string response)))]
                (as-> (session/encrypt *session-secret*
                                       {:user session
                                        :csrf-token (eval 'csrf-token)}) ?
                      (session/cookie ? options)
                      (add-header response "Set-Cookie" ?)))))


(defn- enable-csrf-tokens [&opt options]
  (default options {:skip []})

  (before "*"
          (when (find (partial = (request :route-uri)) (options :skip))
            (break))

          (let [session (session/decrypt *session-secret* request)]
            (when-let [_ (= "POST" method)
                       parsed-body (cond
                                     (multipart/multipart? request)
                                     (multipart/params request)

                                     (form/form? request)
                                     (form/decode (request :text-body))

                                     :else
                                     nil)]

              (unless (csrf/tokens-equal? (csrf/request-token headers parsed-body) (csrf/session-token session))
                (halt @{:status 403 :body "Invalid CSRF Token" :headers @{"Content-Type" "text/plain"}})))

            # set a new token
            (set! csrf-token (get session :csrf-token (csrf/token)))

            # mask the token for forms
            (put request :csrf-token (csrf/mask csrf-token)))))


(defn enable [key &opt val]
  (case key
    :static-files
    (enable-static-files val)

    :sessions
    (enable-sessions val)

    :csrf-tokens
    (enable-csrf-tokens val)))
