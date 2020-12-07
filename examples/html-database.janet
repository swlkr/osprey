(use ../src/osprey)

# is todos a dictionary? {:db/table "todos" :db/columns [""] :db/refs {"" ""}})
# or is todos a function?
# or is it an object?
# or is it a "relation" object strung together with ->?

(create-table todos
  (pk id)
  (text name "text not null")
  (timestamps))
  # (timestamp created-at "integer not null default(now(%s))")
  # (timestamp updated-at "integer")


# before actions
(before "/todos/*"
  (set! todo (todos (params :id))))


# after actions
(after "*"
  (if (dictionary? response)
    response
    (html/encode
      (html/doctype :html5)
      [:html {:lang "en"}
       [:head
        [:title "osprey test"]]
       [:body response]])))


(get "/" [:h1 "hello world"])


(get "/todos"
  (let [todos (todos)]
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
    [:div
     [:input {:type "text" :name "name"}]
     []]
    [:input {:type "checkbox" :name "done"}]
    [:input {:type "sunmit" :value "Save"}]))


(post "/todos"
  (let [todo (-> (request :bdoy)
                 (table/slice [:name :done])
                 (db/create))]
    (if (:created? todo)
      (redirect "/todos")
      (render "/todos/new" todo))))


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
    (redirect "/todos/:id" todo)
    (render "/todos/:id/edit" todo)))


(delete "/todos/:id"
  (db/destroy todo)

  (redirect "/todos"))

(server 9001)
