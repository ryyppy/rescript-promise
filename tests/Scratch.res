type user = {"name": string}
type comment = string
@val external queryComments: string => Js.Promise.t<array<comment>> = "API.queryComments"
@val external queryUser: string => Js.Promise.t<user> = "API.queryUser"

open Promise

queryUser("patrick")
->then(user => {
  // We use `then` instead of `map` to automatically
  // unnest our queryComments promise
  queryComments(user["name"])
})
->map(comments => {
  // comments is now an array<comment>
  Belt.Array.forEach(comments, comment => Js.log(comment))
})
->ignore
