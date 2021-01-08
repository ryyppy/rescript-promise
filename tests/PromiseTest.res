exception MyError(string)

external promiseErrToExn: Js.Promise.error => exn = "%identity"

let p = {
  open Promise

  Promise.reject(MyError("test"))
  ->then(str => {
    Js.log("this should not be reached: " ++ str)
  })
  ->catch(e => {
    switch promiseErrToExn(e) {
    | MyError(str) => Js.log("found MyError: " ++ str)
    | _ => Js.log("Anything else: ")
    }
  })
}

external promiseErrToJsError: Js.Promise.error => Js.Exn.t = "%identity"
let p = {
  open Promise

  let causeErr = () => {
    Js.Exn.raiseError("Some JS error")
  }

  Promise.resolve()
  ->then(_ => {
    causeErr()
  })
  ->catch(e => {
    switch promiseErrToJsError(e)->Js.Exn.message {
    | Some(str) => Js.log("Promise error occurred: " ++ str)
    | _ => Js.log("Anything else")
    }
  })
}

let _ = {
  open Promise

  let place = ref(0)

  let delayedMsg = (ms, msg) => {
    Promise.make((resolve, _) => {
      Js.Global.setTimeout(() => {
        place := place.contents + 1
        resolve(.(place.contents, msg))
      }, ms)->ignore
    })
  }

  let p1 = delayedMsg(1000, "is Anna")
  let p2 = delayedMsg(500, "myName")
  let p3 = delayedMsg(100, "Hi")

  all([p1, p2, p3])->then(arr => {
    // [ [ 3, 'is Anna' ], [ 2, 'myName' ], [ 1, 'Hi' ] ]
    Belt.Array.map(arr, ((place, name)) => {
      Js.log(`Place ${Belt.Int.toString(place)} => ${name}`)
    })
    // Output
    // Place 3 => is Anna
    // Place 2 => myName
    // Place 1 => Hi
  })
}

let _ = {
  open Promise

  let racer = (ms, name) => {
    Promise.make((resolve, _) => {
      Js.Global.setTimeout(() => {
        resolve(. name)
      }, ms)->ignore
    })
  }

  let promises = [racer(1000, "Turtle"), racer(500, "Hare"), racer(100, "Eagle")]

  race(promises)->then(winner => {
    Js.log("Congrats: " ++ winner)
  })
}

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
