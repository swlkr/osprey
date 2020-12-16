(declare-project
  :name "osprey"
  :description "A sinatra inspired web framework for janet"
  :dependencies ["https://github.com/joy-framework/halo2"
                 "https://github.com/joy-framework/cipher"
                 "https://github.com/andrewchambers/janet-uri"
                 "https://github.com/janet-lang/path"]
  :author "Sean Walker"
  :license "MIT"
  :url "https://github.com/swlkr/osprey"
  :repo "git+https://github.com/swlkr/osprey")

(declare-source
  :source @["src/osprey" "src/osprey.janet"])
