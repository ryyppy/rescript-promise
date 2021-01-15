type t<+'a> = Js.Promise.t<'a>

// Not a fan of this extra exception
// ideally we'd be able to create a Js.Exn.Error
// value instead
//
// Created a PR for this
// https://github.com/rescript-lang/rescript-compiler/pull/4905
exception JsError(Js.Exn.t)

let resolve: 'a => t<'a>

@bs.scope("Promise") @bs.val
external reject: exn => t<_> = "reject"

let make: (((. 'a) => unit, (. 'e) => unit) => unit) => t<'a>

let then: (t<'a>, 'a => 'b) => t<'b>

let catch: (t<'a>,  (exn) => 'b) => t<'b>

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
