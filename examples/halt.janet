(use ../src/osprey)


# halt with a 401
(before "*"
        (unless (or (= (request :path) "/")
                    (= (request :path) "/protected"))
          (halt {:status 401 :body "Nope." :headers {"Content-Type" "text/plain"}})))


# after any request that isn't a redirect, slap a layout and html encode
(after "*"
       (if (dictionary? response)
         response
         (ok text/html
             (html/encode
               (doctype :html5)
               [:html {:lang "en"}
                [:head
                 [:title (request :path)]]
                [:body response]]))))

# returns 200
(GET "/"
     [:h1 "welcome to osprey!"])


# halt works in handlers as well
# try curl -v 'localhost:9001?bypass'
(GET "/protected"
     (unless (params :bypass)
       (halt {:status 401 :body "Nope." :headers {"Content-Type" "text/plain"}}))

     [:h1 "Yep!"])


(server 9001)
