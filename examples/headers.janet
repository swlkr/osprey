(use ../src/osprey)

(enable :static-files)

(after "*"
       (put-in response [:headers "X-Powered-By"] "osprey"))

(server 9001)
