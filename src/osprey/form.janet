(import uri)
(import ./helpers :prefix "")


(defn- indexed-param? [str]
  (string/has-suffix? "[]" str))


(defn- body-table [all-pairs]
  (var output @{})
  (loop [[k v] :in all-pairs]
    (let [k (uri/unescape k)
          v (uri/unescape v)]
      (cond
        (indexed-param? k) (let [k (string/replace "[]" "" k)]
                             (if (output k)
                               (update output k array/concat v)
                               (put output k @[v])))
        :else (put output k v))))
  output)


(defn decode [str]
  (when (or (string? str)
            (buffer? str))
    (as-> (string/replace-all "+" "%20" str) ?
          (string/split "&" ?)
          (filter |(not (empty? $)) ?)
          (map |(string/split "=" $) ?)
          (body-table ?)
          (map-keys keyword ?))))


(defn form? [request]
  (string/has-prefix? "application/x-www-form-urlencoded" (get-in request [:headers "Content-Type"] "")))
