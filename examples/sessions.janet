(import ../src/osprey :prefix "")


# enable session cookies
(enable :sessions {:secure false})


# wrap all html responses in the html below
(layout
  (doctype :html5)
  [:html {:lang "en"}
   [:head
    [:title (request :uri)]]
   [:body response]])


(GET "/"
     [:main
      (if (session :session?)
        [:p "yes, there is a session!"]
        [:p "no, there is not a session"])

      # the form helper is only available in route macros
      # it also automatically assigns method to POST
      (form {:action "/create-session"}
            [:input {:type "submit" :value "Sign in"}])

      (form {:action "/delete-session"}
            [:input {:type "submit" :value "Sign out"}])])


(POST "/create-session"
      (session :session? true)

      (redirect "/"))


(POST "/delete-session"
      (session :session? nil)

      (redirect "/"))


(server 9001)
