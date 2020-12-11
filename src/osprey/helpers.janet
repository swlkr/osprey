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


(def text/html @{"Content-Type" "text/html"})
(def text/plain @{"Content-Type" "text/plain"})
(def application/json @{"Content-Type" "application/json"})


(defn ok [headers body]
  @{:status 200
    :body body
    :headers headers})
