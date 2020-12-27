(import ../src/osprey :prefix "")
(import tester :prefix "" :exit true)

(defsuite "readme"
          (test "osprey works"
                (is (deep= @{:status 200 :body "osprey" :headers @{"Content-Type" "text/plain"}}
                           (do
                             (GET "/" "osprey")
                             (app @{:uri "/" :method "GET"}))))))
