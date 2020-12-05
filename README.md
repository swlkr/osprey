# Osprey Web Framework

Osprey is a [sinatra](http://sinatrarb.com) inspired web framework written in [janet](https://github.com/janet-lang/janet)

```clojure
; # myapp.janet
(use osprey)

(get "/" "osprey")

(server 9001)
```

First make sure [janet is installed](https://janet-lang.org/docs/index.html)

Then install osprey:

```sh
jpm install https://github.com/swlkr/osprey
```

### Taking it for a spin

Now that we have some code going let's test it out:

```sh
janet myapp.janet
```

This should start an http server that's listening at http://localhost:9001.

Go ahead and test it with `curl`

```sh
curl localhost:9001
# => osprey
```

That's it for now, happy hacking!
