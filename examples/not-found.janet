(import ../src/osprey :prefix "")

(GET "/" "home")

(not-found
  (content-type "text/html")

  (html/encode
    [:h1 "404 Page not found"]))

(server 9001)
