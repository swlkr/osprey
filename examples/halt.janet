(use ../src/osprey)

(defn protected? [request]
  (or (= (request :path) "/")
      (= (request :path) "/protected")))

# halt with a 401
(before
  (unless (protected? request)
    (halt {:status 401 :body "Nope." :headers {"Content-Type" "text/plain"}})))


# wrap all html responses with layout
(layout
  (doctype :html5)

  [:html {:lang "en"}

   [:head
    [:title (request :path)]]

   [:body response]])


# returns 200
(GET "/"
     [:h1 "welcome to osprey!"])


# halt works in handlers as well
# try curl -v 'localhost:9001?bypass='
(GET "/protected"
     (unless (params :bypass)
       (halt {:status 401 :body "Nope." :headers {"Content-Type" "text/plain"}}))

     [:h1 "Yep!"])


(server 9001)
