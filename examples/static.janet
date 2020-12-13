(use ../src/osprey)

(enable :static-files)

(GET "/" "dynamic")

(server :9001)