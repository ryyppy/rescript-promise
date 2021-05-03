# rescript-promise

This is a proposal for replacing the original `Js.Promise` binding that is shipped within the ReScript compiler. It will be upstreamed as `Js.Promise2` soon. This binding was made to allow our users to try out the implementation in their codebases first.

> See the [PROPOSAL.md](./PROPOSAL.md) for the rationale and design decisions.

**Feature Overview:**

- `t-first` bindings
- Fully compatible with the builtin `Js.Promise.t` type
- `make` for creating a new promise with a `(resolve, reject) => {}` callback
- `resolve` for creating a resolved promise
- `reject` for creating a rejected promise
- `catch` for catching any JS or ReScript errors (all represented as an `exn` value)
- `then` for chaining functions that return another promise
- `thenResolve` for chaining functions that transform the value inside a promise
- `all` and `race` for running promises concurrently
- `finally` for arbitrary tasks after a promise has rejected / resolved
- Globally accessible `Promise` module that doesn't collide with `Js.Promise`

**Non-Goals of `rescript-promise`:**

- No rejection tracking or other complex type hackery
- No special utilities (we will add docs on how to implement common utils on your own)

**Caveats:**

- There are 2 edge-cases where returning a `Promise.t<Promise.t<'a>>` value within `then` / `thenResolve` is not runtime safe (but also quite rare in practise). Refer to the [Common Mistakes](#common-mistakes) section for details.
- These edge-cases shouldn't happen in day to day use, also, for those with general concerns about runtime safetiness, it is recommended to use a `catch` call in the end of each promise chain to prevent runtime crashes anyways (just like in JS).

## Requirements

`bs-platform@8.2` and above.

## Installation

```
npm install @ryyppy/rescript-promise --save
```

Add `@ryyppy/rescript-promise` as a dependency in your `bsconfig.json`:

```json
{
  "bs-dependencies": ["@ryyppy/rescript-promise"]
}
```

This will expose a global `Promise` module (don't worry, it will not mess with your existing `Js.Promise` code).

## Examples

- [examples/FetchExample.res](examples/FetchExample.res): Using the `fetch` api to login / query some data with a full promise chain scenario

## Usage

**Creating a Promise:**

```rescript
let p1 = Promise.make((resolve, _reject) => {
  
  // We use uncurried functions for resolve / reject
  // for cleaner JS output without unintended curry calls
  resolve(. "hello world")
})

let p2 = Promise.resolve("some value")

// You can only reject `exn` values for streamlined catch handling
exception MyOwnError(string)
let p3 = Promise.reject(MyOwnError("some rejection"))
```

**Access and transform a promise value:**

```rescript
open Promise
Promise.resolve("hello world")
->then(msg => {
  // then callbacks require the result to be resolved explicitly
  resolve("Message: " ++ msg)
})
->then(msg => {
  Js.log(msg);

  // Even if there is no result, we need to use resolve() to return a promise
  resolve()
})
->ignore // Requires ignoring due to unhandled return value
```

**Chain promises:**

```rescript
open Promise

type user = {"name": string}
type comment = string

// mock function
let queryComments = (username: string): Js.Promise.t<array<comment>> => {
  switch username {
  | "patrick" => ["comment 1", "comment 2"]
  | _ => []
  }->resolve
}

// mock function
let queryUser = (_: string): Js.Promise.t<user> => {
  resolve({"name": "patrick"})
}

let queryUser = queryUser("u1")
->then(user => {
  // We use `then` to automatically
  // unnest our queryComments promise
  queryComments(user["name"])
})
->then(comments => {
  // comments is now an array<comment>
  Belt.Array.forEach(comments, comment => Js.log(comment))

  // Output:
  // comment 1
  // comment 2

  resolve()
})
->ignore
```

You can also use `thenResolve` to chain a promise, and transform its nested value:

```rescript
open Promise

let createNumPromise = (n) => resolve(n)

createNumPromise(5)
->thenResolve(num => {
  num + 1
})
->thenResolve(num => {
  Js.log(num)
})
->ignore
```

**Catch promise errors:**

**Important:** `catch` needs to return the same return value as its previous `then` call (e.g. if you pass a `promise` of type `Promise.t<int>`, you need to return an `int` in your `catch` callback). This usually implies that you'll need to use a `result` value to express successful / unsuccessful operations:

```rescript
exception MyError(string)

open Promise

Promise.reject(MyError("test"))
->then(str => {
  Js.log("this should not be reached: " ++ str)

  // Here we use the builtin `result` constructor `Ok`
  Ok("successful")->resolve
})
->catch(e => {
  let err = switch e {
  | MyError(str) => "found MyError: " ++ str
  | _ => "Some unknown error"
  }

  // Here we are using the same type (`t<result>`) as in the previous `then` call
  Error(err)->resolve
})
->then(result => {
  let msg = switch result {
  | Ok(str) => "Successful: " ++ str
  | Error(msg) => "Error: " ++ msg
  }
  Js.log(msg)
  resolve()
})
->ignore
```

**Catch promise errors caused by a thrown JS exception:**

```rescript
open Promise

let causeErr = () => {
  Js.Exn.raiseError("Some JS error")->resolve
}

Promise.resolve()
->then(_ => {
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
  resolve()
  // Outputs: Some JS error msg: Some JS error
})
->ignore
```

**Catch promise errors that can be caused by ReScript OR JS Errors (mixed error types):**

Every value passed to `catch` are unified into an `exn` value, no matter if those errors were thrown in JS, or in ReScript. This is similar to how we [handle mixed JS / ReScript errors](https://rescript-lang.org/docs/manual/latest/exception#catch-both-rescript-and-js-exceptions-in-the-same-catch-clause) in synchronous try / catch blocks.

```rescript
exception TestError(string)

let causeJsErr = () => {
  Js.Exn.raiseError("Some JS error")
}

let causeReScriptErr = () => {
  raise(TestError("Some ReScript error"))
}

// imaginary randomizer function
@bs.val external generateRandomInt: unit => int = "generateRandomInt"

open Promise

resolve()
->then(_ => {
  // We simulate a promise that either throws
  // a ReScript error, or JS error
  if generateRandomInt() > 5 {
    causeReScriptErr()
  } else {
    causeJsErr()
  }->resolve
})
->catch(e => {
  switch e {
  | TestError(msg) => Js.log("ReScript Error caught:" ++ msg)
  | JsError(obj) =>
    switch Js.Exn.message(obj) {
    | Some(msg) => Js.log("Some JS error msg: " ++ msg)
    | None => Js.log("Must be some non-error value")
    }
  | _ => Js.log("Some unknown error")
  }
  resolve()
})
->ignore
```

**Using a promise from JS (interop):**

```rescript
open Promise

@val external someAsyncApi: unit => Js.Promise.t<string> = "someAsyncApi"

someAsyncApi()->Promise.then((str) => Js.log(str)->resolve)->ignore
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

all([p1, p2, p3])->then(arr => {
  // arr = [ [ 3, 'is Anna' ], [ 2, 'myName' ], [ 1, 'Hi' ] ]

  Belt.Array.forEach(arr, ((place, name)) => {
    Js.log(`Place ${Belt.Int.toString(place)} => ${name}`)
  })
  // forEach output:
  // Place 3 => is Anna
  // Place 2 => myName
  // Place 1 => Hi

  resolve()
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
->then(winner => {
  Js.log("Congrats: " ++ winner)->resolve
  // Congrats: Eagle
})
->ignore
```

## Common Mistakes

**Don't return a `Promise.t<Promise.t<'a>>` within a `then` callback:**

```rescript
open Promise

resolve(1)
  ->then((value: int) => {
    let someOtherPromise = resolve(value + 2)

    // BAD: this will cause a Promise.t<Promise.t<'a>>
    resolve(someOtherPromise)
  })
  ->then((p: Promise.t<int>) => {
    // p is marked as a Promise, but it's actually an int
    // so this code will fail
    p->then((n) => Js.log(n)->resolve)
  })
  ->catch((e) => {
    Js.log("luckily, our mistake will be caught here");
    Js.log(e)
    // p.then is not a function
    resolve()
  })
  ->ignore
```

**Don't return a `Promise.t<'a>` within a `thenResolve` callback:**

```rescript
open Promise
resolve(1)
  ->thenResolve((value: int) => {
    // BAD: This will cause a Promise.t<Promise.t<'a>>
    resolve(value)
  })
  ->thenResolve((p: Promise.t<int>) => {
    // p is marked as a Promise, but it's actually an int
    // so this code will fail
    p->thenResolve((n) => Js.log(n))->ignore
  })
  ->catch((e) => {
    Js.log("luckily, our mistake will be caught here");
    // e: p.then is not a function
    resolve()
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

## Run Examples

Examples are runnable on node, and require an active internet connection to be able to access external mockup apis.

```
node examples/FetchExample.js
```
