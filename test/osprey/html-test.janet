(import ../../src/osprey/html)
(import tester :prefix "" :exit true)

(defsuite "html test"
          (test "html/encode"
                (is (deep= "<!DOCTYPE HTML><li><a href=\"#\">Text</a>After Text</li>"
                           (html/encode (html/doctype :html5) [:li [:a {:href "#"} "Text"] "After Text"])))))
