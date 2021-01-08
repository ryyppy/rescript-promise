# rescript-promise


```
Promise.make((resolve, reject) => {
  resolve(. 1)
})

Promise.resolve(1)
Promise.reject(2)

let p1 = {
  open Promise

  resolve(1)
    ->then((foo) => {
      foo + 1
    })
    ->then((next) => {
      Js.log(next + 2)
    })
}

exception Nope
let p2 = {
  open Promise

  make((rej, res) => rej(Nope))
    ->then((a: int) => {
      a + 1
    })
}

let p3 = {
  open Promise

  let first = resolve(1)

  resolve(2)
    ->then((_) => {
      first
    })
    ->then((b) => {
      Js.log2("first value: ", b)
    })
}
```





## Development

```
# Building
npm run build

# Watching
npm run watch
```


## Acknowledgements

Heavily inspired by [github.com/aantron/promise](https://github.com/aantron/promise).
