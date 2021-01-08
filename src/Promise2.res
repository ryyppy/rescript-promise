type t<+'a>
type error

@ocaml.doc(`This is a test`)
@bs.new
external make: (@bs.uncurry ((. 'a) => unit, (. exn) => unit) => unit) => t<'a> = "Promise"

/* [make (fun resolve reject -> .. )] */
@bs.val @bs.scope("Promise") external resolve: 'a => t<'a> = "resolve"
@bs.val @bs.scope("Promise") external reject: exn => t<'a> = "reject"

@bs.val @bs.scope("Promise")
external all: array<t<'a>> => t<array<'a>> = "all"

@bs.val @bs.scope("Promise")
external all2: ((t<'a0>, t<'a1>)) => t<('a0, 'a1)> = "all"

@bs.val @bs.scope("Promise")
external all3: ((t<'a0>, t<'a1>, t<'a2>)) => t<('a0, 'a1, 'a2)> = "all"

@bs.val @bs.scope("Promise")
external all4: ((t<'a0>, t<'a1>, t<'a2>, t<'a3>)) => t<('a0, 'a1, 'a2, 'a3)> = "all"

@bs.val @bs.scope("Promise")
external all5: ((t<'a0>, t<'a1>, t<'a2>, t<'a3>, t<'a4>)) => t<('a0, 'a1, 'a2, 'a3, 'a4)> = "all"

@bs.val @bs.scope("Promise")
external all6: ((t<'a0>, t<'a1>, t<'a2>, t<'a3>, t<'a4>, t<'a5>)) => t<(
  'a0,
  'a1,
  'a2,
  'a3,
  'a4,
  'a5,
)> = "all"

@bs.val @bs.scope("Promise")
external race: array<t<'a>> => t<'a> = "race"

@bs.send
external then: (t<'a>, @bs.uncurry ('a => t<'b>)) => t<'b> = "then"

@bs.send
external catch: (t<'a>, @bs.uncurry (error => t<'a>)) => t<'a> = "catch"

@bs.send
external finally: (t<'a>, @bs.uncurry (unit => unit)) => t<'a> = "finally"
