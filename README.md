# rescript-promise

This is a proposal for a better ReScript promise binding that unfortunately **is not** zero-cost, and introduces some small overhead.

> See the [PROPOSAL.md](./PROPOSAL.md) for the rationale and design decisions.

**Quick feature summary:**

- `t-first` bindings
- Fully compatible with `Js.Promise.t`
- Allows nested promises (no `resolve` call on each `then`)
- Has small runtime overhead for fixing nested promises
- No rejection tracking or other complex type hackery
- No special utilities (less things to maintain)

This binding aims to be as close to the JS Promise API as possible.

## Installation (not published yet)

This is experimental and not published yet. Don't use it in production yet.

```
# added to see how an installation might look like
npm install @rescript/rescript-promise --save
```

Until npm release, use install directly from GH instead:

```
# via npm
npm install git+https://github.com/ryyppy/rescript-promise.git --save

# via yarn
yarn add ryyppy/rescript-promise
```

Add `rescript-promise` as a dependency in your `bsconfig.json`:

```json
{
  "bs-dependencies": [
    "rescript-promise"
  ]
}
```

This will expose a global `Promise` module (don't worry, it will not mess with your existing `Js.Promise` code).

## Usage

**Creating a Promise:**

```rescript
let p1 = Promise.make((resolve, _reject) => {
  resolve(. "hello world")
})

let p2 = Promise.resolve("some value")

let p3 = Promise.reject("some rejection")
```

**Chain promises:**

```rescript
let p = {
  open Promise
  Promise.resolve("hello world")
  ->then(msg => {
    Js.log("Message: " ++ msg)
  })
}
```

**Chain nested promises:**

```rescript
type user = {"name": string}
type comment = string
@val external queryComments: string => Js.Promise.t<array<comment>> = "API.queryComments"
@val external queryUser: string => Js.Promise.t<user> = "API.queryUser"

let p = {
  open Promise

  queryUser("patrick")
  ->flatThen(user => {
    // We use flatThen instead of then to automatically
    // unnest our queryComments promise
    queryComments(user["name"])
  })
  ->then(comments => {
    // comments is now an array<comment>
    Belt.Array.forEach(comments, comment => Js.log(comment))
  })
}
```

**Catch promise errors:**

```rescript
exception MyError(string)

external promiseErrToExn: Js.Promise.error => exn = "%identity"

let p = {
  open Promise

  Promise.reject(MyError("test"))
  ->then(str => {
    Js.log("this should not be reached: " ++ str)
  })
  ->catch(e => {
    switch promiseErrToExn(e) {
    | MyError(str) => Js.log("found MyError: " ++ str)
    | _ => Js.log("Anything else: ")
    }
  })
}
```

**Catch promise errors caused by a thrown JS exception:**


```rescript
external promiseErrToJsError: Js.Promise.error => Js.Exn.t = "%identity"

let p = {
  open Promise

  let causeErr = () => {
    Js.Exn.raiseError("Some JS error")
  }

  Promise.resolve()
  ->then(_ => {
    causeErr()
  })
  ->catch(e => {
    switch promiseErrToJsError(e)->Js.Exn.message {
    | Some(str) => Js.log("Promise error occurred: " ++ str)
    | _ => Js.log("Anything else")
    }
  })
}
```

**Using a promise from JS:**

```rescript
@val external someAsyncApi: unit => Js.Promise.t<string> = "someAsyncApi"

someAsyncApi()->Promise.then((str) => Js.log(str))
```


**Running multiple Promises concurrently:**

```rescript
let _ = {
  open Promise

  let place = ref(0)

  let delayedMsg = (ms, msg) => {
    Promise.make((resolve, _) => {
      Js.Global.setTimeout(() => {
        place := place.contents + 1
        resolve(.(place.contents, msg))
      }, ms)->ignore
    })
  }

  let p1 = delayedMsg(1000, "is Anna")
  let p2 = delayedMsg(500, "myName")
  let p3 = delayedMsg(100, "Hi")

  all([p1, p2, p3])->then(arr => {
    // [ [ 3, 'is Anna' ], [ 2, 'myName' ], [ 1, 'Hi' ] ]
    Belt.Array.map(arr, ((place, name)) => {
      Js.log(`Place ${Belt.Int.toString(place)} => ${name}`)
    })
    // Output
    // Place 3 => is Anna
    // Place 2 => myName
    // Place 1 => Hi
  })
}
```

**Race Promises:**

```rescript
let _ = {
  open Promise

  let racer = (ms, name) => {
    Promise.make((resolve, _) => {
      Js.Global.setTimeout(() => {
        resolve(. name)
      }, ms)->ignore
    })
  }

  let promises = [racer(1000, "Turtle"), racer(500, "Hare"), racer(100, "Eagle")]

  race(promises)->then(winner => {
    Js.log("Congrats: " ++ winner)
    // Congrats: Eagle
  })
}
```

## Development

```
# Building
npm run build

# Watching
npm run dev
```

## Run Test

These are not proper tests yet, but you can run the scripts like this:

```
node tests/PromiseTest.js
```

## Acknowledgements

Heavily inspired by [github.com/aantron/promise](https://github.com/aantron/promise).
