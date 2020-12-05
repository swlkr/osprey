(defmacro foreach [binding & body]
  (defglobal (keyword (first binding)) @[])
  ~(map (fn [val]
          (let [,(first binding) val]
            ,;body))
        ,(get binding 1)))


(after "*"
  (html/encode
    (html/doctype :html5)
    [:html {:lang "en"}
     [:head
      [:title "osprey test"]]
     [:body response]]))


(get "/" [:h1 "hello world"])


(before "/todos/*"
  (set! todo (db/find :todos (params :id))))


(get "/todos"
  (let [todos (db/all :todos)]
    [:ul
     (foreach [todo todos]
       [:li
        [:div (todo :name)]
        [:div (if (todo :done) "done!" "")]])]))


(get "/todos/:id"
  [:div (todo :name)]
  [:div (if (todo :done) "done!" "")])


(get "/todos/new"
  (form (action "/todos")
    [:input {:type "text" :name "name"}]
    [:input {:type "checkbox" :name "done"}]
    [:input {:type "sunmit" :value "Save"}]))


(post "/todos"
  (def todo (todo request))

  (if (db/create todo)
    (redirect "/todos")
    (render "/todos/new" todo)))


(get "/todos/:id/edit"
  (form (action "/todos/:id" todo)
    [:input {:type "text" :name "name"}]
    [:div (errors :name)]

    [:input {:type "checkbox" :name "done"}]
    [:div (errors :done)]

    [:input {:type "submit" :value "Save"}]))


(patch "/todos/:id"
  (def new-todo (todo request))

  (if (db/save todo new-todo)
    (redirect "/todos")
    (render "/todos/:id/edit" todo)))


(delete "/todos/:id"
  (db/destroy todo)

  (redirect "/todos"))

(server 9001)
