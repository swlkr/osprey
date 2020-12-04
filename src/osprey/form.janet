(import uri)


(defn map-keys
  `Executes a function on a dictionary's keys and
   returns a struct

   Example

   (map-keys snake-case {:created_at "" :uploaded_by ""}) -> {:created-at "" :uploaded-by ""}
  `
  [f dict]
  (let [acc @{}]
    (loop [[k v] :pairs dict]
      (put acc (f k) v))
    acc))


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
  (when (string? str)
    (as-> (string/replace-all "+" "%20" str) ?
          (string/split "&" ?)
          (filter |(not (empty? $)) ?)
          (map |(string/split "=" $) ?)
          (body-table ?)
          (map-keys keyword ?))))


(defn redirect [uri]
  @{:status 302
    :headers @{"Location" uri}})
