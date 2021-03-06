(import ../src/osprey :prefix "")

(enable :sessions {:secure false})
(enable :csrf-tokens)


# wrap all html responses with layout
(layout
  (doctype :html5)
  [:html {:lang "en"}
   [:head
    [:title (request :uri)]]
   [:body response]])


(GET "/"
     [:div
      [:div "no csrf form. returns 403"]
      [:form {:action "/without-csrf-token" :method "POST"}
       [:input {:type "submit" :value "Submit"}]]

      [:div "csrf token in form. returns 302"]
      (form {:action "/with-csrf-token"}
            [:input {:type "submit" :value "Submit"}])

      [:div "invalid csrf token in form. returns 403"]
      [:form {:action "/with-csrf-token" :method "POST"}
             [:input {:type "hidden" :name "__csrf-token" :value "im invalid"}]
             [:input {:type "submit" :value "Submit"}]]])


(POST "/without-csrf-token"
      (redirect "/"))


(POST "/with-csrf-token"
      (redirect "/"))


(server 9001)
