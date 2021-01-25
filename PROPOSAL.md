# rescript-promise Design

## Introduction

ReScript comes with a `Js.Promise` binding that allows binding to vanilla JS promises. Unfortunately those bindings have two glaring issues that make them unintuitive to use:

1. Current APIs are `t-last` instead of `t-first`, making them hard to use with the `->` operator (the recommended way to pipe in ReScript)
2. Catching errors is unweildy, since it currently uses an abstract type `error` without any guidance on how to extract the information

There's also another issue with chaining promises that resolve nested promises (`Js.Promise.t<Js.Promise.t<'a>>`), which we intentionally didn't fix, because we consider it a rare edge-case. We discuss the problem and the trade-offs with our solution in a separate section.

First let's talk about the two more important problems in detail.

### 1) t-last vs t-first APIs

Right now all functionality within `Js.Promise` are optimized for `|>` usage. Our bindings are designed to be used with the `->` operator.

**Example t-last**

```rescript
let myPromise = Js.Promise.make((~resolve, ~reject) => resolve(. 2))

open Js.Promise

// Note how we need to use the `_` placeholder to be able to use the ->
// operator with pipe-last apis
myPromise
  ->then_(value => {
    Js.log(value)
    resolve(value + 2)
  }, _)->then_(value => {
    Js.log(value)
    resolve(value + 3)
  }, _)->catch(err => {
    Js.log2("Failure!!", err)
    resolve(-2)
  }, _)->ignore
```

We want to change the API in a way that makes it look like this (our new bindings are exposed as the `Promise` module):

```rescript
// Note how `make` doesn't need any labeled arguments anymore -> closer to the JS api!
let myPromise = Promise.make((resolve, _) => resolve(. 2))

open Promise

myPromise
  ->then(value => {
    Js.log(value)
    resolve(value)
  })
  // we also offer a `map` function that spares as the extra `resolve` call
  ->map(value => {
    value + 1
  })
  ->map(value => {
    Js.log(value) // logs 3
  })
  ->ignore
```

We introduce two functions, `then` and `map`, whereas...

- `then` is being used to provide a callbacks that **returns another promise**
- `map` is being used to provide a callback that transforms a value within a Promise chain.

Please note how we also changed the name from `Js.Promise.then_` to `Promise.then`. In ReScript, `then` is not a keyword, so it's perfectly fine to be used as a function name here.

### 2) Error Handling

In the original `Js.Promise` binding, a promise error is encoded as an abstract type `Js.Promise.error`, with no further functionality of accessing the value. Users are supposed to know how to access and transform their value on their own.

**Example:**

```rescript
exception MyError(string)

// Requires some type of unsafe coercion to be able to access the value
external unsafeToExn: Js.Promise.error => exn = "%identity"

Js.Promise.reject(MyError("test"))
  ->Js.Promise.catch(err => {
    switch err->unsafeToExn {
      | MyError(str) => Js.log2("My error occurred: ", str)
      | _ => Js.log("Some other error occurred")
    }
  }, _)
```

Now this solution is problematic in many different ways, because without knowing anything about the encoding of ReScript / JS exceptions, one needs to consider following cases:

- What if `err` is a JS exception thrown through a JS related error?
- What if `err` is actually no exception, but a non-error value? (it is perfectly viable to throw other primitive data types in JS as well)

We think that this leaves too many decisions on correctly handling the type, so it might end up to different solutions in different codebases. We want to unify that process in the following manner:

**Proposed API:**

```rescript
open Promise
exception MyError(string)

Promise.reject(MyError("test"))
  ->Promise.catch(err => {
    switch err {
      | MyError(str) => Js.log2("My error occurred: ", str)
      | JsError(obj) =>
        switch Js.Exn.message(obj) {
          | Some(msg) => Js.log2("JS error message:", msg)
          | None => Js.log("This might be a non-error JS value?")
        }
      | _ => Js.log("Some other (ReScript) error occurred")
    }
  })
```

In future ReScript versions, the `Promise.JsError` exception will be deprecated in favor of the builtin `Js.Exn.Error` exception:

```rescript
// In this version, like in a synchronous try / catch block with mixed
// ReScript / JS Errors, we use the `Js.Exn.Error` case to match on
// JS errors
Promise.reject(MyError("test"))
  ->Promise.catch(err => {
    // err is of type `exn` already - no need to classify it yourself!
    switch err {
      | MyError(str) => Js.log2("My error occurred: ", str)
      | Js.Exn.Error(obj) =>
        switch Js.Exn.message(obj) {
          | Some(msg) => Js.log2("JS error message:", msg)
          | None => Js.log("This might be a non-error JS value?")
        }
      | _ => Js.log("Some other (ReScript) error occurred")
    }
  })
```

The proposed solution takes the burden of classifying the `Js.Promise.error` value, and allows for a similar pattern match as in a normal try / catch block, as explained in our [exception docs](https://rescript-lang.org/docs/manual/latest/exception#catch-both-rescript-and-js-exceptions-in-the-same-catch-clause).


## Nested Promises Issue Trade-offs

As previously mentioned, right now there are two edge cases in our proposed API that allow a potential runtime error, due to the way nested promises auto-collapse in the JS runtime (which is not correctly reflected by the type system).

To get more into detail: In JS whenever you return a promise within a promise chain, `then(() => Promise.resolve(somePromise))` will actually pass down the value that’s inside `somePromise`, instead of passing the nested promise (`Promise.t<Promise.t<'value>>`). This causes the type system to report a different type than the runtime, ultimately causing runtime errors.

**Here are the two edge cases demonstrated with our proposed API:**

```rescript
open Promise

// SCENARIO ONE: resolve a nested promise within `then`

resolve(1) ->map((value: int) => {
    // BAD: This will cause a Promise.t<Promise.t<'a>>
    resolve(value)
  })
  ->map((p: Promise.t<int>) => {
    // p is marked as a Promise, but it's actually an int
    // so this code will fail
    p->map((n) => Js.log(n))->ignore
  })
  ->catch((e) => {
    Js.log("luckily, our mistake will be caught here");
    // e: p.then is not a function
  })
  ->ignore


// SCENARIO TWO: Resolve a promise within `map`

resolve(1)
  ->then((value: int) => {
    let someOtherPromise = resolve(2)

    // BAD: this will cause a Promise.t<Promise.t<'a>>
    resolve(someOtherPromise)
  })
  ->map((p: Promise.t<int>) => {
    // p is marked as a Promise, but it's actually an int
    // so this code will fail
    p->map((n) => Js.log(n))->ignore
  })
  ->catch((e) => {
    Js.log("luckily, our mistake will be caught here");
    // e: p.then is not a function
  })
  ->ignore
```

This topic is not new, and has been solved by different alternative libraries in the Reason ecosystem. For example, see [this discussion in the reason-promise](https://github.com/aantron/promise#discussion-why-js-promises-are-unsafe) repository.

### Why we think the "nested promises" problem is not worth solving

The only way to solve this problem with relatively low effort is by introducing a small runtime layer on top of our Promise resolving mechanism. This runtime would detect resolved promises (nested promises), and put them in a opaque container, so that the JS runtime is not able to auto-collapse the value. Later on when we `then` / `map` on the resulting data, it will be unwrapped again.

In our design process, we implemented both, a runtime version, and a non-runtime version. In the beginning the small runtime overhead didn't feel like such a burden, but after building some real-world examples, we realized that a common usage path seldomly triggers the edge-case.

On the other hand, not using a runtime gives following (in our opinion) huge advantages:

- Readable and predictable JS output
- Less complexity due to the boxing / unboxing nature, that might collide with other existing JS libraries
- Without the extra complexity, it gives us more room in our complexity budget to introduce other, more pressing features instead (e.g. emulated cancelation wrappers)

Readable and predictable JS output is probably the most important one, because our goal is seamless interop and almost human-readable JS code after compilation. Also, in practical use-cases, even if we'd introduce said runtime code to prevent the unnesting problem, it wouldn't actually give us any guarantees that there won't be any error during runtime.

The previously mentioned `reason-promise` tries to tackle all of this dirty edge-cases on multiple levels, but this comes with a complexity cost of introducing two different types to differentiate between `rejectable` and `non-rejectable` promises. This introduces a non-trivial amount of mental overhead, where users are forced to continously categorize between different promises, even if the underlying data structure is the same.

We think it's more practical to just teach one simple `then`, `map`, `all`, `race`, `finally` API, and then tell our users to use a final `catch` on each promise chain, to always be on the runtime safe side even if they make mistakes with our aforementioned edge-cases.

Also, it is pretty hard to get into the edge-case, since there are different warning flags that you are doing something wrong, e.g.:


```rescript
@val external queryUsers: unit => Promise.t<array<string>> = "queryUsers"

open Promise
resolve(1)
  ->map(value => {
    // Let's assume we return a promise here, even though we are not supposed to
    queryUsers()
  })
  // This will cause the next value to be a `Promise.t<int>`, which is not true, because in the JS runtime, it's just an `int`
  ->map((value: Promise.t<array<string>>) => {
    // Now the consumer would be forced to use a `map` within a `map`, which seems unintuitive.
    // The correct way would have been to use a `then` function instead of the `previous` map
    value->map((v) => {
      })
  })
  ->catch((e) => {
    // This catch all clause will luckily protect us from the edge-case above
  })
```

**To sum it up:** We think the upsides of having zero-cost interop, while having familiar JS, outweights the benefits of allowing nested promises, which should hopefully not happen in real world scenarios anyways.

## Compatiblity

Our proposed API exposes a `Promise.t` type that is fully compatible with the original `Js.Promise.t`, so it's easy to use the new bindings in existing codebases with `Js.Promise` code.

## Prior Art

### reason-promise

The most obvious here is the already mentioned [reason-promise](https://github.com/aantron/promise), which was the most prominent inspiration for our proposal.

**The good parts:** The interesting part are the boxing / unboxing mechanism, which allows us to automatically box any non-promise value in a `PromiseBox`, that gets wrapped depending on the value at hand. This code adds some additional runtime overhead on each `then` call, but is arguably small and most likely won't end up in any hot paths. It fixes the nested promises problem quite efficiently.

A few things we also recognized when evaluating the library:

**Non idiomatic APIs:** The APIs are harder to understand, and the library tries to tackle more problems than we care about. E.g. it tracks the `rejectable` state of a promise, which means we need to differentiate between two categories of promises.

It also adds `uncaughtError` handlers, and `result` / `option` based apis, which are easy to build in userspace, and should probably not be part of a core module.

**JS unfriendly APIs:** It has a preference for `map` and `flatMap` over the original `then` naming, probably to satisify its criteria for Reason / OCaml usage (let\* operator), it uses `list` instead of `Array`, which causes unnecessary convertion (e.g. in `Promise.all`. This causes too much overhead to be a low-level solution for Promises in ReScript.

### Other related libraries

- [RationalJS/future](https://github.com/RationalJS/future)
- [wokalski/vow](https://github.com/wokalski/vow)
- [yawaramin/prometo](https://www.npmjs.com/package/@yawaramin/prometo)

All those libraries gave us some good insights on different approaches of tackling promises during runtime, and they are probably a good solution for users who want to go the extra mile for extra type safety features. We wanted to keep it minimalistic though, so we generally went with a simpler approach.

## Conclusion

We think that with the final design, as documented in the [README](./README.md), we evaluated all available options and settled with the most minimalistic version of a `Promise` binding, that allows us to fix up the most pressing problems, and postpone the other mentioned problems to a later point in time. It's easier to argue to add a runtime layer later on, if the edge-cases turned out to be regular cases.
