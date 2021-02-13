# master

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
