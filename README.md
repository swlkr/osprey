# Owl Web Framework

Owl is a sinatra inspired web framework written in [janet](https://github.com/janet-lang/janet)

```clojure
(use owl)

(get "/" "🦉")

(server 9001)
```

## Getting Started

First make sure [janet is installed](https://janet-lang.org/docs/index.html)

After that make a new directory for your owl project, along with a `.janet` file:

```sh
mkdir my-owl-project \
touch my-owl-project/main.janet \
cd my-owl-project \
echo '(use owl) (get "/" "🦉") (server 9001)' > main.janet
```

### Taking it for a spin

Now that we have some code going let's test it out:

```sh
janet main.janet
```

This should start an http server that's listening at http://localhost:9001.

Go ahead and test it with `curl`

```sh
curl localhost:9001
```

This should show that same owl emoji in the terminal!

That's it for now, happy hacking!
