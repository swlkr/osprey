(declare-project
  :name "osprey"
  :description "A sinatra inspired web framework for janet"
  :dependencies ["https://github.com/joy-framework/halo"
                 "https://github.com/janet-lang/json"
                 "https://github.com/andrewchambers/janet-uri"]
  :author "Sean Walker"
  :license "MIT"
  :url "https://github.com/osprey-framework/osprey"
  :repo "https://github.com/osprey-framework/osprey")

(declare-source
  :source @["src/osprey" "src/osprey.janet"])

