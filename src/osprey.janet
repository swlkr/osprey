(import halo)


(def- *headers* @{:content-type :text/plain})
(def- *routes* @[])
(def- *before-fns* @[])
(def- *after-fns* @[])


(defmacro set!
  `set! creates a varglobal in the current env
  and also sets that value when a before or after
  function is executed. Returns nil.

  Example:

  (use osprey)

  (before "/"
    (set! id 1))

  (get "/" id)

  (server 9001)

  curl localhost:9001 => 1`
  [name value]
  (varglobal (keyword name) nil)
  ~(set ,name ,value))


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


(defmacro get [uri & args]
  ~(,add-route :get
               ,uri
               (fn [request]
                 (let [{:params params
                        :body body
                        :headers headers} request]
                   (do ,;args)))))


(defmacro post [uri & args]
  ~(,add-route :post
               ,uri
               (fn [request]
                 (let [{:params params
                        :body body
                        :headers headers} request]
                   (do ,;args)))))


(defmacro patch [uri & args]
  ~(,add-route :patch
               ,uri
               (fn [request]
                 (let [{:params params
                        :body body
                        :headers headers} request]
                   (do ,;args)))))


(defmacro delete [uri & args]
  ~(,add-route :delete
               ,uri
               (fn [request]
                 (let [{:params params
                        :body body
                        :headers headers} request]
                   (do ,;args)))))


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
      (let [response (f request)]
        (run-after-fns response request)))))


(defn add-header [name value]
  (put-in *headers* [name] value))


(defn- add-before [uri args]
  (array/push *before-fns* [uri args]))


(defmacro before [uri & args]
  ~(,add-before ,uri (fn [request]
                       (let [{:headers headers
                              :body body
                              :params params} request]
                          (do ,;args)))))


(defn- add-after [uri args]
  (array/push *after-fns* [uri args]))


(defmacro after [uri & args]
  ~(,add-after ,uri (fn [response &opt request]
                      (do ,;args))))


(defn- use-response [handler]
  (fn [request]
    (when-let [response (handler request)]
      (if (or (string? response)
              (buffer? response))
        @{:status 200
          :headers *headers*
          :body response}

        (update-in response [:headers] merge *headers*)))))


(def- app (-> (handler *routes*)
              (use-response)))


(defn server [&opt port host]
  (default port 0)
  (default host "localhost")

  (halo/server app port))
