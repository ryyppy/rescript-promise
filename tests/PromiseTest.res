let _ = {
  open Promise
  make((resolve, _reject) => {
    resolve(. 1)
  })
  ->flatThen(foo => {
    Js.log(foo + 1)

    let other = resolve("This is working")

    other
  })
  ->then(o => {
    Js.log("Message received: " ++ o)

    "test foo"
  })
  ->then(s => {
    Js.log(s ++ " is a string")
  })
  ->ignore
}

let racer = {
  open Promise
  race([resolve(3), resolve(2)])->then(r => {
    Js.log2("winner: ", r)
  })
}

let foo = {
  open Promise

  make((_, reject) => {
    reject(. "oops")
  })
  ->catch(e => {
    Js.log(e)
    1
  })
  ->then(num => {
    Js.log2("add + 1 to recovered", num + 1)
  })
}

let interop = {
  Js.Promise.resolve("interop promise")
  ->Promise.then(n => {
    Js.log(n)
    Promise.resolve("interop is working")
  })
  ->Promise.then(p => {
    p->Promise.then(msg => Js.log(msg))
  })
}
/*
*/

/*
This is an example that breaks

let controlGroup = {
  open Promise2

  make((resolve, _) => resolve(. Promise2.resolve("actual value")))
  ->then(p => {
    p->then(m => {
      Js.log(m)
      resolve(ignore)
    })
  })
  ->ignore
}
*/
