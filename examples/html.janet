(use ../src/osprey)

# put the todos somewhere
# since there isn't a database
(def todos @[])


# add a response header to return text/html
# to the client
(add-header :content-type :text/html)


# before "/todos/:id"
# set the id to cut down on duplication
(before "/todos/*"
  (when (params :id)
    (set! id (scan-number (params :id))))
  (set! todo (get-in todos [id])))


# before everything try to parse application/x-www-form-urlencoded body
(before "*"
  (update request :body form/decode))


# after any request that isn't a redirect, slap a layout and html encode
(after "*"
  (if (dictionary? response)
    response
    (html/encode
      (html/doctype :html5)
      [:html {:lang "en"}
        [:head
         [:title (string "html.janet example: " (request :uri))]]
        [:body response]])))


(get "/"
  [:div
   [:h1 "welcome to osprey examples/html.janet"]
   [:a {:href "/todos"} "view todos"]])


# the seven CRUD methods
(get "/todos"
  [:div
   [:a {:href "/"} "go home"]
   [:span " "]
   [:a {:href "/todos/new"} "new todo"]
   [:ul
    (foreach [todo todos]
      [:li
       [:span (todo :name)]
       [:span (if (todo :done) " is done!" "")]
       [:div
        [:a {:href (href "/todos/:id/edit" todo)} "edit"]
        [:span " "]
        (form "/todos/:id/delete" todo
          [:input {:type "submit" :value "delete"}])]])]])


(get "/todos/:id/show"
  [:div
   [:span (todo :name)]
   [:span (if (todo :done) " is done!" "")]])


(get "/todos/new"
  (form "/todos"
    [:input {:type "text" :name "name"}]
    [:input {:type "checkbox" :name "done"}]
    [:input {:type "submit" :value "Save"}]))


(post "/todos"
  (array/push todos (put-in body [:id] (length todos)))
  (redirect "/todos"))


(get "/todos/:id/edit"
  (printf "%q" todo)
  (form "/todos/:id/edit" todo
    [:input {:type "text" :name "name" :value (todo :name)}]
    [:input (merge {:type "checkbox" :name "done"} (if (todo :done) {:checked ""} {}))]
    [:input {:type "submit" :value "Save"}]))


# this updates todos in the array
# :id is assumed to be an integer
# since todos is an array
(post "/todos/:id/edit"
  (update todos id merge body)
  (redirect "/todos"))


# this deletes todos from the array
# :id is assumed to be an integer
# since todos is an array
(post "/todos/:id/delete"
  (array/remove todos id)
  (redirect "/todos"))

# start the server on port 9001
(server 9001)
