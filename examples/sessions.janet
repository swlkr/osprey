(use ../src/osprey)

(enable :sessions {:secure false})

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
   (if session
       [:div "yes, there is a session!"]
       [:div "no, there is not a session"])

   (form "/sessions"
         [:input {:type "submit" :value "Sign in"}])

   (form "/sessions/delete"
         [:input {:type "submit" :value "Sign out"}])])

(POST "/sessions"
  (set session "session")

  (redirect "/"))

(POST "/sessions/delete"
  (set session nil)

  (redirect "/"))

(server 9001)
