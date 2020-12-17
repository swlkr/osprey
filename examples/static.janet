(use ../src/osprey)

(enable :static-files)

(GET "/dynamic" "dynamic")

(server :9001)
