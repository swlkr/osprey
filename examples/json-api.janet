(use ../src/osprey)
(import json)

# put the todos somewhere
# since there isn't a database
(def todos @[])

# before everything try to parse json body
(before "*"
        (when (and body (not (empty? body)))
          (update request :body json/decode)))

# before "/todos/:id"
# set the id so you don't have to scan-number the (params :id) twice
(before "/todos/*"
        (set! id (scan-number (or (params :id) ""))))

# after any request return json encoded values
(after "*"
       (ok application/json
           (-> response json/encode freeze)))

# just a nice status message on root
(GET "/" {:status "up"})

# here's the meat and potatoes
# return the todos array from earlier
(GET "/todos"
     todos)

# this appends todos onto the array
(POST "/todos"
      (array/push todos body))

# this updates todos in the array
# :id is assumed to be an integer
# since todos is an array
(PATCH "/todos/:id"
       (update todos id merge body))

# this deletes todos from the array
# :id is assumed to be an integer
# since todos is an array
(DELETE "/todos/:id"
        (array/remove todos id))

# start the server on port 9001
(server 9001)
