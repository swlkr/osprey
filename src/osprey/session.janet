(import cipher)
(import jdn)
(import ./helpers :prefix "")


(def cookie-peg (peg/compile '{:main (some (sequence :pair (opt "; ")))
                               :pair (sequence (capture :key) (opt "=") (capture :value))
                               :value (opt :allowed)
                               :key :allowed
                               :allowed (some (if-not (set "=;") 1))}))


(defn find-cookie [request name]
  (as-> (get-in request [:headers "Cookie"] "") ?
        (peg/match cookie-peg ?)
        (or ? [])
        (struct ;?)
        (get ? name)))


(defn decrypt [key request]
  (when-let [cookie (find-cookie request "session")]
    (try
      (as-> cookie ?
            (cipher/decrypt key ?)
            (jdn/decode ?))
      ([_] nil))))


(defn encrypt [key value]
  (->> (jdn/encode value)
       (cipher/encrypt key)))


(defn cookie [session options]
  (def default-options {:samesite "Lax"
                        :httponly true
                        :path "/"
                        :secure true})

  (let [{:samesite samesite
         :httponly httponly
         :path path
         :secure secure
         :domain domain
         :expires expires
         :max-age max-age} (merge default-options options)

        parts [(string "session=" session)
               (if samesite (string "SameSite=" samesite) "")
               (if httponly "HttpOnly" "")
               (if path (string "Path=" path) "")
               (if secure "Secure" "")
               (if domain (string "Domain=" domain) "")
               (if expires (string "Expires=" expires) "")
               (if max-age (string "Max-Age=" max-age) "")]]

    (-> (filter (comp not empty?) parts)
        (string/join "; "))))
