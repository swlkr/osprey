(import ../src/osprey :prefix "")


(layout
  (doctype :html5)
  [:html
   [:head
    [:title (request :path)]]
   [:body response]])


(layout :a
  (doctype :html5)
  [:html
   [:head
    [:title (request :path)]]
   [:body
    [:h1 "/a"]
    response]])


(layout :b
  (doctype :html5)
  [:html
   [:head
    [:title (request :path)]]
   [:body
    [:h1 "/b"]
    response]])


(before "/a*"
        (use-layout :a))


(GET "/"
     [:h1 "home"])


(GET "/a"
     (use-layout :a)

     [:div "/a!"])


(GET "/a/1"
     [:div "/a/1!"])


(GET "/b"
     (use-layout :b)

     [:div "/b!"])


(server 9001)
