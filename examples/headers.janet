(use ../src/osprey)

(enable :static-files)

(before "*"
        (header "X-Powered-By" "osprey"))

(server 9001)
