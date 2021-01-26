(use ../src/osprey)

(enable :logging (fn [s _ _]
                   (def dur (* 1000 (- (os/clock) s)))
                   (print "Hey it took " dur "ms." (if (> 0.02 dur) " Not bad!"))))

(GET "/" "HI")

(server "8000")
