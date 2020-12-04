(use ../src/osprey)
(import json)

# put the todos somewhere
# since there isn't a database
(def todos @[])

# add a response header to return application/json
# to the client
(add-header :content-type :application/json)

# before everything try to parse json body
(before "*"
  (when body
    (update request :body json/decode)))

# before "/todos/:id"
# set the id so you don't have to scan-number the (params :id) twice
(before "/todos/*"
  (set! id (scan-number (or (params :id) ""))))

# after any request return json encoded values
(after "*"
  (json/encode response))

# just a nice status message on root
(get "/" {:status "up"})

# here's the meat and potatoes
# return the todos array from earlier
(get "/todos"
  todos)

# this appends todos onto the array
(post "/todos"
  (array/push todos body))

# this updates todos in the array
# :id is assumed to be an integer
# since todos is an array
(patch "/todos/:id"
  (update todos id merge body))

# this deletes todos from the array
# :id is assumed to be an integer
# since todos is an array
(delete "/todos/:id"
  #(printf "%q" id)
  (array/remove todos id))

# start the server on port 9001
(server 9001)
