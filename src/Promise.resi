// The +'a marks the abstract type parameter as covariant, which essentially means that
// a value of type 'a is immutable and may not be used in some mutable context.
//
// This makes sense for promises, since according to their specification, once a promise has
// been resolved (with a specific value), it will never change its resolved value.
//
// More details about polymorphism / invariance / covariance,... can be found here:
// https://caml.inria.fr/pub/docs/manual-ocaml/polymorphism.html#ss:variance:abstract-data-types
type t<+'a> = Js.Promise.t<'a>

// JsError is currently a shim exception and will be deprecated for future
// ReScript versions.
//
// See following merged PR in the compiler (waiting for next version release):
// https://github.com/rescript-lang/rescript-compiler/pull/4905
exception JsError(Js.Exn.t)

@ocaml.doc("
[resolve(value)] creates a resolved Promise with a given `value`

```rescript
let p = Promise.resolve(5) // Promise.t<int>
```
")
let resolve: 'a => t<'a>

@bs.scope("Promise") @bs.val
external reject: exn => t<_> = "reject"

@ocaml.doc("
[make(callback)] creates a new Promise based on a `callback` that receives two
uncurried functions `resolve` and `reject` for defining the Promise's result.

```rescript
let n = 4
Promise.make((resolve, reject) => {
  if(n < 5) {
    resolve(. \"success\")
  }
  else {
    reject(. \"failed\")
  }
})
->map(str => {
  Js.log(str)
})
->catch(e => {
  Js.log(\"Error occurred\")
})
->ignore
```
")
let make: (((. 'a) => unit, (. 'e) => unit) => unit) => t<'a>

@ocaml.doc("
[map(promise, callback)] converts an encapsulated value of a promise into
another promise wrapped value. Really useful if you don't want to chain multiple
promise operations together.

```rescript
resolve(\"Anna\")
->map(str => {
  \"Hello \" ++ str
})
->map(str => {
  Js.log(str)
})
->ignore // Ignore needed for side-effects
```

In case you want to return another promise in your `callback`,
consider using \`then\` instead.
")
let map: (t<'a>, 'a => 'b) => t<'b>

@ocaml.doc("
[catch(promise, errorCallback)] registers an exception handler in a promise chain.
The `errorCallback` receives an `exn` value that can later be refined into a JS error or ReScript
error.

```rescript
exception SomeError(string)
reject(SomeError(\"this is an error\"))
->map(_ => {
  Ok(\"This result will never be returned\")
})
->catch(e => {
  let msg = switch(e) {
    | SomeError(msg) => \"ReScript error occurred: \" ++ msg
    | JsError(obj) =>
      switch Js.Exn.message(obj) {
        | Some(msg) => \"JS exception occurred: \" ++ msg
        | None => \"Some other JS value has been thrown: \" ++ obj
      }
    | _ => \"Unexpected error occurred\"
  }

  Error(msg)
})
->map(result => {
  switch result {
  | Ok(r) => Js.log2(\"Operation successful: \", r)
  | Error(msg) => Js.log2(\"Operation failed: \", msg)
  }
})
->ignore // Ignore needed for side-effects
```

In case you want to return another promise in your `callback`,
consider using \`then\` instead.
")
let catch: (t<'a>,  (exn) => 'a) => t<'a>

@ocaml.doc("
[then(promise, callback)] returns a new promise based on the result of `promise`'s value. 
The `callback` needs to explicitly return a new promise via `resolve`.

```rescript
Promise.resolve(5)
->then(num => {
  resolve(num + 5)
})
->map(num => {
  Js.log2(\"Your lucky number is: \", num);
})
->ignore
```

In case you want to convert a promise's value to another value, consider using `map` instead.
")
let then: (t<'a>, 'a => t<'b>) => t<'b>

@ocaml.doc("
[finally(promise, callback)] is used to execute a function that is called no matter if a promise
was resolved or rejected. It will return the same `promise` it originally received.
```rescript
exception SomeError(string)
let isDone = ref(false)

resolve(5)
->then(_ => {
  reject(TestError(\"test\"))
})
->map(v => {
  Js.log2(\"final result\", v)
})
->catch(_ => {
  Js.log(\"Error handled\")
})
->finally(() => {
  Js.log(\"finally\")
  isDone := true
})
->map(() => {
  Js.log2(\"isDone:\", isDone.contents)
})
->ignore
```
")
@bs.send external finally: (t<'a>, unit => unit) => t<'a> = "finally"

/* Combining promises. */
@bs.scope("Promise") @bs.val
external race: array<t<'a>> => t<'a> = "race"

@ocaml.doc("
[all(promises)] runs all promises in parallel and returns a new promise resolving all gathered results in a unified array.

```rescript
open Promise
let promises = [resolve(1), resolve(2), resolve(3)]

all(promises)
->map((results) => {
  Belt.Array.forEach(results, (num) => {
    Js.log2(\"Number: \", num)
  })
})
->ignore
```
")
let all: array<t<'a>> => t<array<'a>>

@ocaml.doc("
[all(p1, p2)]. Like `all()`, but with a fixed size tuple of 2
")
let all2: (t<'a>, t<'b>) => t<('a, 'b)>

@ocaml.doc("
[all(p1, p2)]. Like `all()`, but with a fixed size tuple of 3
")
let all3: (t<'a>, t<'b>, t<'c>) => t<('a, 'b, 'c)>

@ocaml.doc("
[all(p1, p2)]. Like `all()`, but with a fixed size tuple of 4
")
let all4: (t<'a>, t<'b>, t<'c>, t<'d>) => t<('a, 'b, 'c, 'd)>

@ocaml.doc("
[all(p1, p2)]. Like `all()`, but with a fixed size tuple of 5
")
let all5: (t<'a>, t<'b>, t<'c>, t<'d>, t<'e>) => t<('a, 'b, 'c, 'd, 'e)>

@ocaml.doc("
[all(p1, p2)]. Like `all()`, but with a fixed size tuple of 6
")
let all6: (t<'a>, t<'b>, t<'c>, t<'d>, t<'e>, t<'f>) => t<('a, 'b, 'c, 'd, 'e, 'f)>
