(import ../src/osprey :prefix "")


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

      (form {:action "/sessions"}
            [:input {:type "submit" :value "Sign in"}])

      (form {:action "/sessions/delete"}
            [:input {:type "submit" :value "Sign out"}])])


(POST "/sessions"
      (session :session? true)

      (redirect "/"))


(POST "/sessions/delete"
      (session :session? nil)

      (redirect "/"))


(server 9001)
