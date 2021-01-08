type t<+'a> = Js.Promise.t<'a>
type error = Js.Promise.error

let resolve: 'a => t<'a>

@bs.scope("Promise") @bs.val
external reject: 'e => t<_> = "reject"

let make: (((. 'a) => unit, (. 'e) => unit) => unit) => t<'a>

let then: (t<'a>, 'a => 'b) => t<'b>

@bs.send
external catch: (t<'a>, @bs.uncurry (error => 'b)) => t<'b> = "catch"

let flatThen: (t<'a>, 'a => t<'b>) => t<'b>

/* Combining promises. */
@bs.scope("Promise") @bs.val
external race: array<t<'a>> => t<'a> = "race"

let all: array<t<'a>> => t<array<'a>>

let all2: (t<'a>, t<'b>) => t<('a, 'b)>

let all3: (t<'a>, t<'b>, t<'c>) => t<('a, 'b, 'c)>

let all4: (t<'a>, t<'b>, t<'c>, t<'d>) => t<('a, 'b, 'c, 'd)>

let all5: (t<'a>, t<'b>, t<'c>, t<'d>, t<'e>) => t<('a, 'b, 'c, 'd, 'e)>

let all6: (t<'a>, t<'b>, t<'c>, t<'d>, t<'e>, t<'f>) => t<('a, 'b, 'c, 'd, 'e, 'f)>
