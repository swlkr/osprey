# Osprey

Osprey is a [sinatra](http://sinatrarb.com) inspired framework for writing web applications in [janet](https://github.com/janet-lang/janet) quickly

```clojure
(use osprey)

(GET "/" "osprey")

(server 9001)
```

Make sure janet and osprey are installed (macOS)

```sh
brew install janet
jpm install https://github.com/swlkr/osprey
```

Add the example code above to a `.janet` file:

```sh
echo '(use osprey) (GET "/" "osprey") (server 9001)' > myapp.janet
janet myapp.janet
```

Make sure it's working with curl

```sh
curl localhost:9001
# => osprey
```

That's it for now, happy hacking!
