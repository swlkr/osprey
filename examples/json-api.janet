(use ../src/osprey)
(import json)


# put the todos somewhere
# since there isn't a database
(def todos @[])


# before everything try to parse json body
(before
  (content-type "application/json")

  (when (and body (not (empty? body)))
    (update request :body json/decode))

  # before urls with :id
  (when (params :id)
    (update-in request [:params :id] scan-number)))


# just a nice status message on root

# try this
# $ curl -v localhost:9001
(GET "/"
     (json/encode {:status "up"}))


# here's the meat and potatoes
# return the todos array from earlier

# try this
# $ curl -v localhost:9001/todos
(GET "/todos"
     (json/encode todos))


# this appends todos onto the array

# try this
# $ curl -v -X POST -H "Content-Type: application/json" --data '{"todo": "buy whole wheat bread"}' localhost:9001/todos
(POST "/todos"
      (json/encode (array/push todos body)))


# this updates todos in the array
# :id is assumed to be an integer
# since todos is an array

# try this
# $ curl -v -X PATCH -H "Content-Type: application/json" --data '{"todo": "buy whole grain bread"}' localhost:9001/todos/0
(PATCH "/todos/:id"
       (json/encode (update todos (params :id) merge body)))


# this deletes todos from the array
# :id is assumed to be an integer
# since todos is an array

# try this
# $ curl -v -X DELETE localhost:9001/todos/0
(DELETE "/todos/:id"
        (json/encode (array/remove todos (params :id))))


# start the server on port 9001
(server 9001)
