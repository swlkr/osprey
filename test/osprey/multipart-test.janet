(import ../../src/osprey/multipart)
(import tester :prefix "" :exit true)

(defsuite "multipart"
          (test "multipart parsing works"
                (is (deep= @{:__csrf-token "05f57ebf2265388a72dda844e69ffc92ffd2ad23545d664e14ba630c6d0949a5150082650dfa3764b6e211e08379231fb96db77a39bb410089d291c0719f90af"
                             :email "test12@example.com"}
                           (multipart/params @{:headers @{"Content-Type" "multipart/form-data; boundary=----WebKitFormBoundary2KcsybfKqIt05O6D"}
                                               :body "------WebKitFormBoundary2KcsybfKqIt05O6D\r\nContent-Disposition: form-data; name=\"__csrf-token\"\r\n\r\n05f57ebf2265388a72dda844e69ffc92ffd2ad23545d664e14ba630c6d0949a5150082650dfa3764b6e211e08379231fb96db77a39bb410089d291c0719f90af\r\n------WebKitFormBoundary2KcsybfKqIt05O6D\r\nContent-Disposition: form-data; name=\"email\"\r\n\r\ntest12@example.com\r\n------WebKitFormBoundary2KcsybfKqIt05O6D--"})))))
