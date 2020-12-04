(use ../src/osprey)
(import ../src/osprey/html)
(import ../src/osprey/form)


# put the todos somewhere
# since there isn't a database
(def todos @[])


# add a response header to return text/html
# to the client
(add-header :content-type :text/html)


# before "/todos/:id"
# set the id to cut down on duplication
(before "/todos/*"
  (set! id (params :id))
  (set! todo (get todos id)))


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


# just a nice hello world on root
(get "/" [:h1 "hello world"])


# helper for todos loop
(defn todo/li [todo]
  [:li
   [:span (todo :name)]
   [:span (if (todo :done) " is done!" "")]])


# the seven CRUD methods
(get "/todos"
  [:ul
   (map todo/li todos)])


(get "/todos/:id"
  [:div
   [:span (todo :name)]
   [:span (if (todo :done) " is done!" "")]])


(get "/todos/new"
  [:form {:action "/todos" :method :post}
    [:input {:type "text" :name "name"}]
    [:input {:type "checkbox" :name "done"}]
    [:input {:type "sunmit" :value "Save"}]])


(post "/todos"
  (array/push todos body)
  (form/redirect "/todos"))


(get "/todos/:id/edit"
  [:form {:action (string "/todos/:id" (params :id))
          :method :patch}
    [:input {:type "text" :name "name"}]
    [:input {:type "checkbox" :name "done"}]
    [:input {:type "submit" :value "Save"}]])


# this updates todos in the array
# :id is assumed to be an integer
# since todos is an array
(patch "/todos/:id"
  (update todos id merge body)
  (form/redirect "/todos"))


# this deletes todos from the array
# :id is assumed to be an integer
# since todos is an array
(delete "/todos/:id"
  (array/remove todos id)
  (form/redirect "/todos"))

# start the server on port 9001
(server 9001)
