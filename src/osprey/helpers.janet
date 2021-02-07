(defmacro set!
  `
  Deprecated. You probably don't want this.

  WARNING: this is a *global variable* that persists
  between requests. Be sure you know what you are doing if
  you use this.

  set! creates a varglobal and also sets
  that value when a before or after
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


(defn timestamp
  "Get the current date nicely formatted"
  []
  (let [date (os/date)
        M (+ 1 (date :month))
        D (+ 1 (date :month-day))
        Y (date :year)
        HH (date :hours)
        MM (date :minutes)
        SS (date :seconds)]
    (string/format "%d-%.2d-%.2d %.2d:%.2d:%.2d"
                   Y M D HH MM SS)))


(defmacro foreach [binding & body]
  ~(map (fn [val]
          (let [,(first binding) val]
            ,;body))
        ,(get binding 1)))


(def text/html @{"Content-Type" "text/html; charset=UTF-8"})
(def text/plain @{"Content-Type" "text/plain"})
(def application/json @{"Content-Type" "application/json; charset=UTF-8"})


(defn ok [headers body]
  @{:status 200
    :body body
    :headers headers})


(defn inspect [val]
  (printf "%m" val)
  val)


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
