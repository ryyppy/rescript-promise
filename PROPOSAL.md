# rescript-promise Design Proposal

## Introduction

ReScript comes with a `Js.Promise` binding that allows binding to vanilla JS promises. Unfortunately they come with some (deal breaking) issues that make them hard to use, and in some cases, unusable.

Let's describe the problems and potential solutions for the official Promise bindings.

## Challenges

### 1) t-last vs t-first APIs

Right now all functionality within `Js.Promise` are optimized for `|>` usage. Our bindings are designed to be used with the `->` operator.

**Example t-last**

```rescript
let myPromise = Js.Promise.make((~resolve, ~reject) => resolve(. 2))

open Js.Promise
myPromise->then_(value => {
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

### 2) Nested Promises Cause Runtime Errors

In JS, whenever you return a promise within a promise chain, the value of the promise will always be unwrapped in the JS runtime.That means, `then(() => Promise.resolve(newPromise))` will actually pass down the value that’s inside `newPromise`, instead of passing the whole promise. This causes the type system to report a different type than the runtime, ultimately causing runtime errors.

Here is a minimal reproducible example of the problem:

```rescript
open Promise

myPromise->then(n => {
    let nested = make((resolve, _) => {resolve(. n + 10)})

    resolve(nested)
    },_)->then((f: Promise2.t<int>) => {
      // during runtime, f will be an int
      // so if you'd try to unwrap that value with `f->then()`, it will blow up
      // with a `f doesn't have a function then() defined`
      Js.log(f)
      resolve(0)
      })

p->Promise.then(v => {
  Js.log2("value: ", v)
  Promise2.resolve(ignore())
}, _)->ignore
```

Also refer to the [discussion in the reason-promise](https://github.com/aantron/promise#discussion-why-js-promises-are-unsafe) repository.

### 3) The need for an explicit `resolve`

To be fair, this is more of a UX issue than a technical issue, but in the current bindings, we need to call `Js.Promise.resolve()` for each `then` body to satisfy our interface.

This is a very common source of confusion for our users whenever they want to transform a value within a promise chain:

```rescript
p->Promise.then(v => {
  Js.log2("value: ", v)

  // Especially resolving `unit` is a really annoying detail
  // oftentimes we just want to log something and be done with it
  Promise.resolve(ignore())
}, _)->ignore
```

### 4) Compatibility

It's important to not break too many users when considering a new promise proposal. Types should match up and seamlessly interop with `Js.Promise.t`. Overhead should be small / zero-cost if possible.

## Prior Art

### reason-promise

The most obvious here is the already mentioned [reason-promise](https://github.com/aantron/promise), which was the most prominent inspiration for our proposal.

**The good parts:** The interesting part are the boxing / unboxing mechanism, which allows us to automatically box any non-promise value in a `PromiseBox`, that gets wrapped depending on the value at hand. This code adds some additional runtime overhead on each `then` call, but is arguably small and most likely won't end up in any hot paths. It fixes problem 2 and 3 quite elegantly.

Why don't we just use `reason-promise` as our new implementation then? Let's go into the parts we didn't like when evaluating the library:

**Non idiomatic APIs:** The APIs are not easy to understand, and the library tries to tackle more problems than we care about. E.g. it tracks the `rejectable` state of a promise, which means we need to differentiate between two categories of promises.

It also adds `uncaughtError` handlers, and `result` / `option` based apis, which are easy to build in userspace, and should probably not be part of a core module.

**JS unfriendly APIs:** Instead of `then`, it refers to `map`, etc. It also uses `list` instead of `Array`, which causes unnecessary convertion (e.g. in `Promise.all`. This causes too much overhead to be a low-level solution for Promises in ReScript.

### Other related libraries

- [RationalJS/future](https://github.com/RationalJS/future)
- [wokalski/vow](https://github.com/wokalski/vow)
- [yawaramin/prometo](https://www.npmjs.com/package/@yawaramin/prometo)

All of them more or less doing too much, or trying to fix up Promises, instead of taking them as they are.

## Solution

Actually, the real solution would be special compiler support for promises, which requires a lot of knowledge about the different use-cases and problem domain before one can even attempt such solution.

For now, a binding with some runtime correction needs to suffice. The APIs are kept to a minimum, which hopefully allows an easy migration path as soon as a proper solution has been found.

### JS friendly Binding

Our solution is a `t-first` version of the original `Js.Promise` bindings, but with the `box` and `unbox` runtime of `reason-promise`. 

- The API is designed as closely as possible to the official JS Promise APIs
- `then` allows returning nested promises without runtime errors (solves Problem 2). It also helps unnesting values that can be consumed with a consecutive `map` call.
- `map` allows returning a value that is not necessarily a Promise for easier value transformation (solves Problem 3) 
- We use the `Js.Promise.t` type, so users can just use it without with existing `Js.Promise.t` based code without any extra convertions 

Check out the Usage section of our [README](./README.md) for detailed API usage.
