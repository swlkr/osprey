(import uri)
(import ./helpers :prefix "")


(defn multipart? [request]
  (let [content-type (get-in request [:headers "Content-Type"])]
    (string/has-prefix? "multipart/form-data" content-type)))


(defn- boundary [request]
  (first (peg/match '(sequence "multipart/form-data; boundary=" (capture (some 1)))
                    (get-in request [:headers "Content-Type"] ""))))


(defn- decode-part [part]
  (if (and (= "form-data" (get part "Content-Disposition"))
           (get part "value"))
    (update part "value" uri/unescape)
    part))


(defn decode [request]
  (when-let [boundary (boundary request)
             parts (peg/match ~{:main (some (sequence "--" ,boundary (opt "--") :crlf (group (sequence :header :crlf :crlf (constant "value") :value)) :crlf))
                                :header (sequence (capture "Content-Disposition") ":" :s+ (capture (to ";")) ";" :s+ :name)
                                :name (sequence (capture "name") "=\"" (capture (to "\"")) "\"")
                                :value (capture (to :crlf))
                                :crlf "\r\n"}
                              (get request :body ""))]

    (->> (map (partial apply table) parts)
         (map decode-part))))


(defn params
  `This function converts multipart form data to a single dictionary.
   Multiple parts with the same name will be coerced into an array of values.

   Example:

   (params {:headers {"Content-Type" "multipart/form-data; boundary=---whatever"}
            :body "-----whatever\r\nContent-Disposition: form-data; name=\"test\"\r\n\r\nthis is a test\r\n-----whatever--\r\n"})

   =>

   @{:test "this is a test"}`
  [request]
  (->> (decode request)
       (mapcat (fn [dict] [(keyword (get dict "name")) (get dict "value")]))
       (apply table)))
