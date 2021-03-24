type t<+'a> = Js.Promise.t<'a>

exception JsError(Js.Exn.t)
external unsafeToJsExn: exn => Js.Exn.t = "%identity"

@bs.new
external make: ((@bs.uncurry (. 'a) => unit, (. 'e) => unit) => unit) => t<'a> = "Promise"

@bs.val @bs.scope("Promise")
external resolve: 'a => t<'a> = "resolve"

@bs.send external then: (t<'a>, @uncurry ('a => t<'b>)) => t<'b> = "then"

@bs.send
external thenResolve: (t<'a>, @uncurry ('a => 'b)) => t<'b> = "then"

@bs.send external finally: (t<'a>, unit => unit) => t<'a> = "finally"

@bs.scope("Promise") @bs.val
external reject: exn => t<_> = "reject"

@bs.scope("Promise") @bs.val
external all: array<t<'a>> => t<array<'a>> = "all"

@bs.scope("Promise") @bs.val
external all2: ((t<'a>, t<'b>)) => t<('a, 'b)> = "all"

@bs.scope("Promise") @bs.val
external all3: ((t<'a>, t<'b>, t<'c>)) => t<('a, 'b, 'c)> = "all"

@bs.scope("Promise") @bs.val
external all4: ((t<'a>, t<'b>, t<'c>, t<'d>)) => t<('a, 'b, 'c, 'd)> = "all"

@bs.scope("Promise") @bs.val
external all5: ((t<'a>, t<'b>, t<'c>, t<'d>, t<'e>)) => t<('a, 'b, 'c, 'd, 'e)> = "all"

@bs.scope("Promise") @bs.val
external all6: ((t<'a>, t<'b>, t<'c>, t<'d>, t<'e>, t<'f>)) => t<('a, 'b, 'c, 'd, 'e, 'f)> = "all"

@bs.send
external _catch: (t<'a>, @bs.uncurry (exn => t<'a>)) => t<'a> = "catch"

let catch = (promise, callback) => {
  _catch(promise, err => {
    // In future versions, we could use the better version:
    /* callback(Js.Exn.anyToExnInternal(e)) */

    // for now we need to bring our own JsError type
    let v = if Js.Exn.isCamlExceptionOrOpenVariant(err) {
      err
    } else {
      JsError(unsafeToJsExn(err))
    }
    callback(v)
  })
}

@bs.scope("Promise") @bs.val
external race: array<t<'a>> => t<'a> = "race"
