(import ../src/osprey :prefix "")


(enable :sessions {:secure false})


# put the todos somewhere
# since there isn't a database
(def todos @{0 {:id 0 :name "Osprey" :done "true"}})


(defn coerce [body]
  (if (dictionary? body)
    (do
      (var output @{})

      (eachp [k v] body
        (put output k
             (cond
               (= "false" v) false
               (= "true" v) true
               (peg/match :d+ v) (scan-number v)
               :else v)))

      output)
    body))


# before all requests use naive coerce fn on params
(before "*"
        (update request :params coerce))


# before "/todos/:id"
# set the id and todo var
(before "/todos/*"
        (when (params :id)
          (set! id (params :id)))

        (set! todo (todos id)))


# after any request that isn't a redirect, slap a layout and html encode
(layout
  (doctype :html5)

  [:html {:lang "en"}
   [:head
    [:title (request :path)]]
   [:body
    [:a {:href "/"} "go home"]
    [:span " "]
    [:a {:href "/todos"} "view todos"]
    [:span " "]
    [:a {:href "/todo"} "new todo"]
    response]])


# checkbox helper
(defn checkbox [attributes]
  [[:input {:type "hidden" :name (attributes :name) :value false}]
   (let [attrs {:type "checkbox" :name (attributes :name) :value true}]
     (if (attributes :checked)
       [:input (merge attributes attrs)]
       [:input attrs]))])


(GET "/"
     [:h1 "welcome to osprey"])


# list of todos
(GET "/todos"
     [:div

      (when-let [message (get flash :notice)]
        [:p message])

      [:ul
       (foreach [todo (->> todos values (sort-by |($ :id)))]
                [:li
                 [:span (todo :name)]
                 [:span (if (todo :done) " is done!" "")]
                 [:div
                  [:a {:href (href "/todos/:id/edit" todo)} "edit"]
                  [:span " "]
                  (form {:action (href "/todos/:id/delete" todo)}
                        [:input {:type "submit" :value "delete"}])]])]])


(GET "/todos/:id"
     [:div
      [:span (todo :name)]
      [:span (if (todo :done) " is done!" "")]])


(GET "/todo"
     (form {:action "/todos"}
           [:div
            [:label "name"]
            [:br]
            [:input {:type "text" :name "name"}]
            (when-let [err (get-in request [:errors :name])]
              [:div err])]

           (checkbox {:name "done" :checked (get todo :done)})
           [:label "Done"]

           [:input {:type "submit" :value "Save"}]))


(POST "/todos"
      (let [id (-> todos keys length)
            todo (put params :id id)]

        (if (empty? (params :name))
          (render "/todo" (merge request {:errors {:name "name is blank"}}))

          (do
            (put todos id todo)
            (redirect "/todos")))))


(GET "/todos/:id/edit"
     (form {:action (href "/todos/:id/update" todo)}
           [:div
            [:label "Name"]
            [:br]
            [:input {:type "text" :name "name" :value (todo :name)}]]

           (checkbox {:name "done" :checked (todo :done)})
           [:label "Done"]

           [:input {:type "submit" :value "Save"}]))


# this updates todos in the dictionary
(POST "/todos/:id/update"
      (update todos id merge params)
      (redirect "/todos"))


# this deletes todos from the dictionary
(POST "/todos/:id/delete"
      (put flash :notice "Todo deleted successfully")

      (put todos id nil)

      (redirect "/todos"))


# start the server on port 9001
(server 9001)
