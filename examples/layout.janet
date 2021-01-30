(import ../src/osprey :prefix "")

(layout
  (doctype :html5)
  [:html
   [:head
    [:title (request :path)]]
   [:body response]])

(GET "/"
  [:h1 "home"])

(server 9001)
