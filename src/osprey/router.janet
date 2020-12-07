(import halo)
(import ./helpers :prefix "")

(def- *headers* @{:content-type :text/plain})
(def- *routes* @[])
(def- *before-fns* @[])
(def- *after-fns* @[])

(defn- slash-suffix [p]
  (if (keyword? (last p))
    (put p (dec (length p)) :slash-param)
    p))


(defn- wildcard-params [patt uri]
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
          @[]))))


(defn- route-param? [val]
  (string/has-prefix? ":" val))


(defn- route-param [val]
  (if (route-param? val)
    val
    (string ":" val)))


(defn- route-params [app-url uri]
  (let [app-parts (string/split "/" app-url)
        req-parts (string/split "/" uri)]
    (as-> (interleave app-parts req-parts) ?
          (partition 2 ?)
          (filter (fn [[x]] (route-param? x)) ?)
          (map (fn [[x y]] @[(keyword (drop 1 x)) (first (string/split "?" y))]) ?)
          (mapcat identity ?)
          (table ;?))))


(defn- add-route [method uri f]
  (array/push *routes* [method uri f]))


(defmacro get
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :get
                   ,$uri
                   (fn [request]
                     (let [{:params params
                            :body body
                            :headers headers} request]
                       (do ,;*osprey-args*)))))))


(defmacro post
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :post
                   ,$uri
                   (fn [request]
                     (let [{:params params
                            :body body
                            :headers headers} request]
                       (do ,;*osprey-args*)))))))


(defmacro put
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :put
                   ,$uri
                   (fn [request]
                     (let [{:params params
                            :body body
                            :headers headers} request]
                       (do ,;*osprey-args*)))))))


(defmacro patch
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :patch
                   ,$uri
                   (fn [request]
                     (let [{:params params
                            :body body
                            :headers headers} request]
                       (do ,;*osprey-args*)))))))


(defmacro delete
  [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-route :delete
                   ,$uri
                   (fn [request]
                     (let [{:params params
                            :body body
                            :headers headers} request]
                       (do ,;*osprey-args*)))))))


(defn- part? [[s1 s2]]
  (or (= s1 s2)
      (string/find ":" s1)))


(def- parts '(some (* "/" '(any (+ :a :d (set ":%$-_.+!*'(),"))))))


(defn- route? [request app-route]
  (let [[route-method route-url] app-route
        {:uri uri :method method} request
        uri (first (string/split "?" uri))]

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
  (find (partial route? request) routes))


(defn- run-before-fns [request]
  (each [patt f] *before-fns*
    (when (any? (wildcard-params patt (request :uri)))
      (f request))))


(defn- run-after-fns [response request]
  (var res response)

  (each [patt f] *after-fns*
    (when (any? (wildcard-params patt (request :uri)))
      (set res (f res request))))

  res)


(defn- handler
  "Creates a handler function from routes. Returns nil when handler/route doesn't exist."
  [routes]
  (fn [request]
    (when-let [route (find-route routes request)
               [method uri] route
               f (last route)
               wildcard (wildcard-params uri (request :uri))
               params (or (route-params uri (request :uri)) @{})
               request (merge request {:params params :wildcard wildcard})]

      # run all before-fns before request
      (run-before-fns request)

      # run all after-fns after request
      (let [response (f request)
            response (run-after-fns response request)]

        (if (dictionary? response)
          (update-in response [:headers] merge *headers*)

          @{:status 200
            :headers *headers*
            :body (string response)})))))


(defn add-header [name value]
  (put-in *headers* [name] value))


(defn- add-before [uri args]
  (array/push *before-fns* [uri args]))


(defmacro before [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-before ,$uri (fn [request]
                            (let [{:headers headers
                                   :body body
                                   :params params} request]
                               (do ,;*osprey-args*)))))))


(defn- add-after [uri args]
  (array/push *after-fns* [uri args]))


(defmacro after [uri & *osprey-args*]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (,add-after ,$uri (fn [response &opt request]
                           (let [{:headers headers
                                  :body body
                                  :params params} request]
                             (do ,;*osprey-args*)))))))


(def- app (handler *routes*))


(defn server [&opt port host]
  (default port 0)
  (default host "localhost")

  (halo/server app port))


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


(defn form [str & form-args]
  (let [[params] form-args
        params (if (dictionary? params) params @{})
        body (if (dictionary? (first form-args)) (drop 1 form-args) form-args)
        uri (route-url str params)]
    [:form @{:method "post" :action uri}
      ;body]))


(defn add-logging []
  (var start-seconds 0)
  (var end-seconds 0)

  (before "*"
    (set start-seconds (os/clock)))

  (after "*"
    (set end-seconds (os/clock))
    (printf "[%s] %s=%s %s=%s %s=%.1fms" (timestamp) "uri" (request :uri) "method" (request :method) "duration" (- end-seconds start-seconds))
    response))
