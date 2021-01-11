type t<+'a> = Js.Promise.t<'a>
type error = Js.Promise.error

exception JsError(Js.Exn.t)

%%bs.raw(`
function PromiseBox(p) {
    this.nested = p;
};
function unbox(value) {
    if (value instanceof PromiseBox)
        return value.nested;
    else
        return value;
}
function box(value) {
    if (value != null && typeof value.then === 'function')
        return new PromiseBox(value);
    else
        return value;
}
function _make(executor) {
    return new Promise(function (resolve, reject) {
        var boxingResolve = function(value) {
            resolve(box(value));
        };
        executor(boxingResolve, reject);
    });
};
function _resolve(value) {
    return Promise.resolve(box(value));
};

function _flatThen(promise, callback) {
    return promise.then(function (value) {
        return callback(unbox(value));
    });
};

function _then(promise, callback) {
    return promise.then(function (value) {
        return _resolve(callback(unbox(value)));
    });
};
`)

@bs.val
external unbox: 'a => 'a = "unbox"

@bs.val
external make: ((@bs.uncurry (. 'a) => unit, (. 'e) => unit) => unit) => t<'a> = "_make"

external unsafeToExn: error => exn = "%identity"
external unsafeToJsExn: error => Js.Exn.t = "%identity"

let handleError = e => {
  /* Js.Exn.unsafeAnyToExn(e) */
  if unsafeToExn(e)->Js.Exn.isCamlExceptionOrOpenVariant {
    unsafeToExn(e)
  } else {
    JsError(unsafeToJsExn(e))
  }
}

@bs.val
external resolve: 'a => t<'a> = "_resolve"

/* @bs.val */
/* external resolveU: (. 'a) => t<'b> = "resolve" */

@bs.val
external flatThen: (t<'a>, 'a => t<'b>) => t<'b> = "_flatThen"

/* let then = (promise, callback) => flatThen(promise, v => resolveU(. callback(v))) */

@bs.val
external then: (t<'a>, 'a => 'b) => t<'b> = "_then"

@bs.scope("Promise") @bs.val
external reject: exn => t<_> = "reject"

@bs.scope("Promise") @bs.val
external jsAll: 'a => 'b = "all"

let all = promises => then(jsAll(promises), promises => Js.Array2.map(promises, unbox))

let all2 = (p1, p2) => jsAll((p1, p2))

let all3 = (p1, p2, p3) => jsAll((p1, p2, p3))

let all4 = (p1, p2, p3, p4) => jsAll((p1, p2, p3, p4))

let all5 = (p1, p2, p3, p4, p5) => jsAll((p1, p2, p3, p4, p5))

let all6 = (p1, p2, p3, p4, p5, p6) => jsAll((p1, p2, p3, p4, p5, p6))

@bs.send
external catch: (t<'a>, @bs.uncurry (error => 'b)) => t<'b> = "catch"

@bs.scope("Promise") @bs.val
external race: array<t<'a>> => t<'a> = "race"
