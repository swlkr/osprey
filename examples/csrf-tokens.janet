(use ../src/osprey)

(enable :sessions {:secure false})
(enable :csrf-tokens)

# before all requests try to parse application/x-www-form-urlencoded body
# and use naive coerce fn
(before "*"
        (update request :body form/decode))

# after any request that isn't a redirect, slap a layout and html encode
(after "*"
       (if (dictionary? response)
         response
         (ok text/html
             (html/encode
               (doctype :html5)
               [:html {:lang "en"}
                [:head
                 [:title (request :uri)]]
                [:body response]]))))

(GET "/"
     [:div
      [:div "no csrf form. returns 403"]
      [:form {:action "/without-csrf-token" :method "POST"}
       [:input {:type "submit" :value "Submit"}]]

      [:div "csrf token in form. returns 302"]
      (form "/with-csrf-token"
            [:input {:type "submit" :value "Submit"}])])

(POST "/without-csrf-token"
      (redirect "/"))

(POST "/with-csrf-token"
      (redirect "/"))

(server 9001)
