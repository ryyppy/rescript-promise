/*
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
*/

exception TestError(string)

let fail = msg => {
  Js.Exn.raiseError(msg)
}

let equal = (a, b) => {
  a == b
}

let creationTest = () => {
  /* Test.run(__POS_OF__("Create a promise"), ) */

  /* let p1 = Promise.resolve() */
  ()
}

module ThenChaining = {
  // A promise should be able to return a nested
  // Promise and also flatten it to ease the access
  // to the actual value
  let testFlatThen = () => {
    open Promise
    resolve(1)
    ->flatThen(first => {
      resolve(first + 1)
    })
    ->then(value => {
      Test.run(__POS_OF__("Should be 2"), value, equal, 2)
    })
  }

  // Promise.then should allow both, non-promise and
  // promise values as a return value and correctly
  // interpret the value in the chained then call
  let testThen = () => {
    open Promise

    resolve(1)
    ->then(_ => {
      "simple string"
    })
    ->then(str => {
      Test.run(__POS_OF__("Should be 'simple string'"), str, equal, "simple string")

      resolve(str)
    })
    ->then(p => {
      // Here we are explicitly accessing the promise without flatThen
      p->then(str => {
        Test.run(__POS_OF__("Should still be simple string"), str, equal, "simple string")
      })
    })
  }

  let runTests = () => {
    testFlatThen()->ignore
    testThen()->ignore
  }
}

module Rejection = {
  // Should gracefully handle a exn passed via reject()
  let testExnRejection = () => {
    let cond = "Expect rejection to contain a TestError"
    open Promise

    TestError("oops")
    ->reject
    ->catch(e => {
      Test.run(__POS_OF__(cond), e, equal, TestError("oops"))
    })
    ->ignore
  }

  let runTests = () => {
    testExnRejection()->ignore
  }
}

module Catching = {
  let asyncParseFail: unit => Js.Promise.t<string> = %raw(`
  function() {
    return new Promise((resolve) => {
      var result = JSON.parse("{..");
      return resolve(result);
    })
  }
  `)

  // Should correctly capture an JS error thrown within
  // a Promise `then` function
  let testExternalPromiseThrow = () => {
    open Promise

    asyncParseFail()
    ->then(_ => ()) // Since our asyncParse will fail anyways, we convert to Promise.t<unit> for our catch later
    ->catch(e => {
      let success = switch e {
      | JsError(err) => Js.Exn.message(err) == Some("Unexpected token . in JSON at position 1")
      | _ => false
      }

      Test.run(__POS_OF__("Should be a parser error with Unexpected token ."), success, equal, true)
    })
  }

  // Should correctly capture an exn thrown in a Promise
  // `then` function
  let testExnThrow = () => {
    open Promise

    resolve()
    ->then(_ => {
      raise(TestError("Thrown exn"))
    })
    ->catch(e => {
      let isTestErr = switch e {
      | TestError("Thrown exn") => true
      | _ => false
      }
      Test.run(__POS_OF__("Should be a TestError"), isTestErr, equal, true)
    })
  }

  // Should correctly capture a JS error raised with Js.Exn.raiseError
  // within a Promise then function
  let testRaiseErrorThrow = () => {
    open Promise

    let causeErr = () => {
      Js.Exn.raiseError("Some JS error")
    }

    resolve()
    ->then(_ => {
      causeErr()
    })
    ->catch(e => {
      let isTestErr = switch e {
      | JsError(err) => Js.Exn.message(err) == Some("Some JS error")
      | _ => false
      }
      Test.run(__POS_OF__("Should be some JS error"), isTestErr, equal, true)
    })
  }

  // Should recover a rejection and use then to
  // access the value
  let thenAfterCatch = () => {
    open Promise
    resolve()
    ->flatThen(_ => {
      // NOTE: if then is used, there will be an uncaught
      // error
      reject(TestError("some rejected value"))
    })
    ->catch(e => {
      let s = switch e {
      | TestError("some rejected value") => "success"
      | _ => "not a test error"
      }
      s
    })
    ->then(msg => {
      Test.run(__POS_OF__("Should be success"), msg, equal, "success")
    })
  }

  let runTests = () => {
    testExternalPromiseThrow()->ignore
    testExnThrow()->ignore
    testRaiseErrorThrow()->ignore
    thenAfterCatch()->ignore
  }
}

module Concurrently = {
  let testParallel = () => {
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
      let exp = [(3, "is Anna"), (2, "myName"), (1, "Hi")]
      Test.run(__POS_OF__("Should have correct placing"), arr, equal, exp)
    })
  }

  let testRace = () => {
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
      Test.run(__POS_OF__("Eagle should win"), winner, equal, "Eagle")
    })
  }

  let runTests = () => {
    testParallel()->ignore
    testRace()->ignore
  }
}

creationTest()
ThenChaining.runTests()
Rejection.runTests()
Catching.runTests()
Concurrently.runTests()
