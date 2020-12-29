(import cipher)


(def PADLENGTH 32)


(defn- xor-byte-strings [str1 str2]
  (let [arr @[]
        bytes1 (string/bytes str1)
        bytes2 (string/bytes str2)]
    (when (= (length bytes2) (length bytes1) PADLENGTH)
      (loop [i :range [0 PADLENGTH]]
        (array/push arr (bxor (get bytes1 i) (get bytes2 i))))
      (string/from-bytes ;arr))))


(defn mask [unmasked-token]
  (let [pad (os/cryptorand PADLENGTH)
        masked-token (xor-byte-strings pad unmasked-token)]
    (cipher/bin2hex (string pad masked-token))))


(defn- unmask [masked-token]
  (when masked-token
    (let [token (cipher/hex2bin masked-token)
          pad (string/slice token 0 PADLENGTH)
          csrf-token (string/slice token PADLENGTH)]
      (xor-byte-strings pad csrf-token))))


(defn request-token [headers body]
  (let [token (or (get headers "X-CSRF-Token")
                  (get body :__csrf-token))]
    (unmask token)))


(defn session-token [session]
  (get session :csrf-token))


(defn token []
  (os/cryptorand PADLENGTH))


(defn tokens-equal? [req-token session-token]
  (when (and req-token session-token)
    (cipher/secure-compare req-token session-token)))
