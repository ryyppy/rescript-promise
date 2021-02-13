# master

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

# v0.0.2

- Initial release
