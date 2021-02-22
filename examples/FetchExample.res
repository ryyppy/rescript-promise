// This is only needed for polyfilling the `fetch` API in
// node, so we can run this example on the commandline
module NodeFetchPolyfill = {
  type t
  @module external fetch: t = "node-fetch"
  @val external globalThis: 'a = "globalThis"
  globalThis["fetch"] = fetch
}

/*

In this example, we are accessing a REST endpoint by doing two async operations:
- Login with a valid user and retrieve a Bearer token
- Use the token in our next call to retrieve a list of products

We factor our code in two submodules: Login and Product.

Both modules bind to their own specialized version of `fetch` in the global scope,
and specify the return type to their resulting data structures.

Results are not formally verified (decoded), so we made type assumptions on our
incoming data, and depending on its results, return a `result` value to signal
error or success cases.

We also use some `catch` calls to either short-circuit operations that have failed,
or to catch failed operations to unify into a `result` value.
*/

// Fetch uses a `Response` object that offers a `res.json()` function to retrieve
// a json result. We use a json based api, so we create a binding to access this feature.
module Response = {
  type t<'data>
  @send external json: t<'data> => Promise.t<'data> = "json"
}

module Login = {
  // This is our type assumption for a /login query return value
  // In case the operation was successful, the response will contain a `token` field,
  // otherwise it will return an `{"error": "msg"}` value that signals an unsuccessful login
  type response = {"token": Js.Nullable.t<string>, "error": Js.Nullable.t<string>}

  @val @scope("globalThis")
  external fetch: (
    string,
    'params,
  ) => Promise.t<Response.t<{"token": Js.Nullable.t<string>, "error": Js.Nullable.t<string>}>> =
    "fetch"

  let login = (email: string, password: string) => {
    open Promise

    let body = {
      "email": email,
      "password": password,
    }

    let params = {
      "method": "POST",
      "headers": {
        "Content-Type": "application/json",
      },
      "body": Js.Json.stringifyAny(body),
    }

    fetch("https://reqres.in/api/login", params)
    ->then(res => {
      Response.json(res)
    })
    ->then(data => {
      // Notice our pattern match on the "error" / "token" fields
      // to determine the final result. Be aware that this logic highly
      // depends on the backend specificiation.
      switch Js.Nullable.toOption(data["error"]) {
      | Some(msg) => Error(msg)
      | None =>
        switch Js.Nullable.toOption(data["token"]) {
        | Some(token) => Ok(token)
        | None => Error("Didn't return a token")
        }
      }->resolve
    })
    ->catch(e => {
      let msg = switch e {
      | JsError(err) =>
        switch Js.Exn.message(err) {
        | Some(msg) => msg
        | None => ""
        }
      | _ => "Unexpected error occurred"
      }
      Error(msg)->resolve
    })
  }
}

module Product = {
  type t = {id: int, name: string}

  @val @scope("globalThis")
  external fetch: (string, 'params) => Promise.t<Response.t<{"data": Js.Nullable.t<array<t>>}>> =
    "fetch"

  let getProducts = (~token: string, ()) => {
    open Promise

    let params = {
      "Authorization": `Bearer ${token}`,
    }

    fetch("https://reqres.in/api/products", params)
    ->then(res => {
      res->Response.json
    })
    ->then(data => {
      let ret = switch Js.Nullable.toOption(data["data"]) {
      | Some(data) => data
      | None => []
      }
      Ok(ret)->resolve
    })
    ->catch(e => {
      let msg = switch e {
      | JsError(err) =>
        switch Js.Exn.message(err) {
        | Some(msg) => msg
        | None => ""
        }
      | _ => "Unexpected error occurred"
      }
      Error(msg)->resolve
    })
  }
}

exception FailedRequest(string)

let _ = {
  open Promise
  Login.login("emma.wong@reqres.in", "pw")
  ->Promise.then(ret => {
    switch ret {
    | Ok(token) =>
      Js.log("Login successful! Querying data...")
      Product.getProducts(~token, ())
    | Error(msg) => reject(FailedRequest("Login error - " ++ msg))
    }
  })
  ->then(result => {
    switch result {
    | Ok(products) =>
      Js.log("\nAvailable Products:\n---")
      Belt.Array.forEach(products, p => {
        Js.log(`${Belt.Int.toString(p.id)} - ${p.name}`)
      })
    | Error(msg) => Js.log("Could not query products: " ++ msg)
    }->resolve
  })
  ->catch(e => {
    switch e {
    | FailedRequest(msg) => Js.log("Operation failed! " ++ msg)
    | _ => Js.log("Unknown error")
    }
    resolve()
  })
}
