exception TestError(string)

// Catching scenarios

// 1) Promise is rejected via reject()
// 2) Promise throws a JS error
// 3) Promise raises an exn
// 4) Promise throws a non JS error

/*
switch getExn(e) {
  | Js.Exn.Error(err) => ...
  | TestError(msg) => ...
}
*/
let asyncParseFail: unit => Promise.t<string> = %raw(`
  function() {
    return new Promise((resolve, reject) => {
      var result = JSON.parse("{..");
      return resolve(result);
    })
  }
  `)

let throwPlainValue: unit => unit = %raw(` 
 function() { 
 throw "test" 
 } 
`)

open Promise

let _ =
  Promise.resolve("hello")
  ->then(msg => {
    resolve(msg)
  })
  ->then(p => {
    p->then(_ => {
      "test"
    })
  })
  ->flatThen(_ => {
    asyncParseFail()
    ->then(v => Ok(v))
    ->catch(e => {
      /* Js.log("error caught") */
      /* Js.log(e) */
      Error(e)
    })
  })
  ->catch(e => {
    Error(e)
  })

let _ =
  Promise.resolve(())
  ->flatThen(_ => {
    Js.log("unreachable")
    asyncParseFail()
  })
  ->catch(e => {
    Js.log2("error", e)
    "test"
  })
  ->then(v => {
    Js.log2("result: ", v)
  })


// As a side-effect

/*

p.then((v) => {
  return Promise.resolve("foo") // box(Promise)
})
.then((v) => {
  // unbox
  // 
  return Promise.resolve(unbox(prom))
})




*/
