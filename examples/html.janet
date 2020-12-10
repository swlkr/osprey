(use ../src/osprey)

# put the todos somewhere
# since there isn't a database
(def todos @{})


# add a response header to return text/html
# to the client
(add-header :content-type :text/html)


# coerce false/true and numbers
# since there is no database :(
(defn coerce [body]
  (when (dictionary? body)
    (var output @{})

    (eachp [k v] body
      (put-in output [k]
        (cond
          (= "false" v) false
          (= "true" v) true
          (peg/match :d+ v) (scan-number v)
          :else v)))

    output))


# before all requests try to parse application/x-www-form-urlencoded body
# and use naive coerce fn
(before "*"
  (-> request
      (update :body form/decode)
      (update :body coerce)
      (update :params coerce)))


# before "/todos/:id"
# set the id and todo var
(before "/todos/*"
  (when (params :id)
    (set! id (params :id)))
  (set! todo (todos id)))


# after any request that isn't a redirect, slap a layout and html encode
(after "*"
  (if (dictionary? response)
    response
    (html/encode
      (doctype :html5)
      [:html {:lang "en"}
        [:head
         [:title (request :uri)]]
        [:body response]])))


(GET "/"
  [:div
   [:h1 "welcome to osprey"]
   [:a {:href "/todos"} "view todos"]])


# list of todos
(GET "/todos"
  [:div
   [:a {:href "/"} "go home"]
   [:span " "]
   [:a {:href "/todo"} "new todo"]
   [:ul
    (foreach [todo (->> todos values (sort-by |($ :id)))]
      [:li
       [:span (todo :name)]
       [:span (if (todo :done) " is done!" "")]
       [:div
        [:a {:href (href "/todos/:id/edit" todo)}
          "edit"]
        [:span " "]
        (form "/todos/:id/delete" todo
         [:input {:type "submit" :value "delete"}])]])]])


(GET "/todos/:id"
  [:div
   [:span (todo :name)]
   [:span (if (todo :done) " is done!" "")]])


(GET "/todo"
  (form "/todos"
   [:input {:type "text" :name "name"}]
   [:input {:type "hidden" :name "done" :value false}]
   [:input {:type "checkbox" :name "done" :value true}]
   [:input {:type "submit" :value "Save"}]))


(POST "/todos"
  (let [id (-> todos keys length)
        todo (put-in body [:id] id)]
    (put-in todos [id] todo))

  (redirect "/todos"))


(GET "/todos/:id/edit"
  (form "/todos/:id/update" todo
   [:input {:type "text" :name "name" :value (todo :name)}]
   [:input {:type "hidden" :name "done" :value false}]
   [:input (merge {:type "checkbox" :name "done" :value true} (if (todo :done) {:checked ""} {}))]
   [:input {:type "submit" :value "Save"}]))


# this updates todos in the dictionary
(POST "/todos/:id/update"
  (update todos id merge body)
  (redirect "/todos"))


# this deletes todos from the dictionary
(POST "/todos/:id/delete"
  (put-in todos [id] nil)
  (redirect "/todos"))


# start the server on port 9001
(server 9001)
