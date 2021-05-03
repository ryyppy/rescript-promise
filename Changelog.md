# master

# v2.1.0

- Add the `thenResolve` function, which is essentially the `map` function we removed in v1, but with a better name (thanks @mrmurphy for the suggestion)

# v2.0

**Breaking**

- `catch` was not aligned with `then` and didn't return a `t<'a>`. This change forces users to resolve a value within a `catch` callback.

```diff
Promise.resolve(1)
-  ->catch(err => {
-    ()
-  })
+  ->catch(err => {
+    resolve()
+  })
```

**Note:** This also aligns with the previous `Js.Promise.catch_`.

# v1.0

**Breaking**

- Removed `map` function to stay closer to JS api. To migrate, replace all `map` calls with `then`, and make sure you return a `Js.Promise.t` value in the `then` body, e.g.

```diff
Promise.resolve(1)
-  ->map(n => {
-    n + 1
-  })
+  ->then(n => {
+    resolve(n + 1)
+  })
```

**Bug fixes**

- Fixes an issue where `Promise.all*` are mapping to the wrong parameter list (should have been tuples, not variadic args)

# v0.0.2

- Initial release
