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
  "bs-dependencies": ["rescript-promise"]
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

// You can only reject `exn` values for streamlined catch handling
exception MyOwnError(string)
let p3 = Promise.reject(MyOwnError("some rejection"))
```

**Chain promises:**

```rescript
open Promise
Promise.resolve("hello world")
->map(msg => {
  // `map` allows the transformation of a nested promise value
  Js.log("Message: " ++ msg)
})
->ignore // Requires ignoring due to unhandled return value
```

**Chain nested promises:**

```rescript
type user = {"name": string}
type comment = string
@val external queryComments: string => Js.Promise.t<array<comment>> = "API.queryComments"
@val external queryUser: string => Js.Promise.t<user> = "API.queryUser"

open Promise

queryUser("patrick")
->then(user => {
  // We use `then` instead of `map` to automatically
  // unnest our queryComments promise
  queryComments(user["name"])
})
->map(comments => {
  // comments is now an array<comment>
  Belt.Array.forEach(comments, comment => Js.log(comment))
})
->ignore
```

**Catch promise errors:**

**Important:** `catch` needs to return the same return value as its previous `then` call.

```rescript
exception MyError(string)

open Promise

Promise.reject(MyError("test"))
->map(str => {
  Js.log("this should not be reached: " ++ str)
  Ok("successful")
})
->catch(e => {
  let err = switch e {
  | MyError(str) => "found MyError: " ++ str
  | _ => "Some unknown error"
  }
  Error(err)
})
->map(result => {
  let msg = switch result {
  | Ok(str) => "Successful: " ++ str
  | Error(msg) => "Error: " ++ msg
  }
  Js.log(msg)
})
->ignore
```

**Catch promise errors caused by a thrown JS exception:**

```rescript
open Promise

let causeErr = () => {
  Js.Exn.raiseError("Some JS error")
}

Promise.resolve()
->map(_ => {
  causeErr()
})
->catch(e => {
  switch e {
  | JsError(obj) =>
    switch Js.Exn.message(obj) {
    | Some(msg) => Js.log("Some JS error msg: " ++ msg)
    | None => Js.log("Must be some non-error value")
    }
  | _ => Js.log("Some unknown error")
  }
})
->ignore
```

**Using a promise from JS:**

```rescript
@val external someAsyncApi: unit => Js.Promise.t<string> = "someAsyncApi"

someAsyncApi()->Promise.map((str) => Js.log(str))->ignore
```

**Running multiple Promises concurrently:**

```rescript
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

all([p1, p2, p3])->map(arr => {
  // [ [ 3, 'is Anna' ], [ 2, 'myName' ], [ 1, 'Hi' ] ]
  Belt.Array.map(arr, ((place, name)) => {
    Js.log(`Place ${Belt.Int.toString(place)} => ${name}`)
  })
  // Output
  // Place 3 => is Anna
  // Place 2 => myName
  // Place 1 => Hi
})
->ignore
```

**Race Promises:**

```rescript
open Promise

let racer = (ms, name) => {
  Promise.make((resolve, _) => {
    Js.Global.setTimeout(() => {
      resolve(. name)
    }, ms)->ignore
  })
}

let promises = [racer(1000, "Turtle"), racer(500, "Hare"), racer(100, "Eagle")]

race(promises)
->map(winner => {
  Js.log("Congrats: " ++ winner)
  // Congrats: Eagle
})
->ignore
```

## Development

```
# Building
npm run build

# Watching
npm run dev
```

## Run Test

Runs all tests

```
node tests/PromiseTest.js
```

## Acknowledgements

Heavily inspired by [github.com/aantron/promise](https://github.com/aantron/promise).
