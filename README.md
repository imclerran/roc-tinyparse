# roc-tinyparse
A small parser combinator library for roc.

[![Roc-Lang][roc_badge]][roc_link]
[![GitHub last commit][last_commit_badge]][last_commit_link]
[![CI status][ci_status_badge]][ci_status_link]
[![Latest release][version_badge]][version_link]


## Examples
```roc
expect 
    parser = string("Hello")
    parser("Hello, world!") == Ok(("Hello", ", world!"))

expect
    parser = string("Hello")
    parser("Hello, world!") |> finalize_lazy == Ok("Hello")

expect
    parser = string("Hello") |> lhs(comma) |> lhs(whitespace) |> both(string("world")) 
    parser("Hello, world!") |> finalize_lazy == Ok(("Hello", "world"))
```
```roc
dot = char |> filter(|c| c == '.')

expect
    pattern = maybe(string("v")) |> rhs(integer) |> lhs(dot) |> both(integer) |> lhs(dot) |> both(integer)
    parser = pattern |> map(|((major, minor), patch)| Ok({major, minor, patch}))
    parser("v1.2.34") |> finalize == Ok({major: 1, minor: 2, patch: 34 })

major = integer |> map(|n| Ok(Major(n)))

minor = maybe(dot |> rhs(integer)) |> map(|maybe_n|
        when maybe_n is
            Some(n) -> Ok(Minor(n))
            None -> Ok(NoMinor)
    )

patch = maybe(dot |> rhs(integer)) |> map(|maybe_n|
        when maybe_n is
            Some(n) -> Ok(Patch(n))
            None -> Ok(NoPatch)
    )

expect
    parser = rhs(maybe(string("v")), zip_3(major, minor, patch))
    parser("v1.2.34_abc") |> finalize_lazy == Ok((Major(1), Minor(2), Patch(34)))
```


<!-- LINKS -->
[roc_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fpastebin.com%2Fraw%2FcFzuCCd7
[roc_link]: https://github.com/roc-lang/roc
[ci_status_badge]: https://img.shields.io/github/actions/workflow/status/imclerran/roc-tinyparse/ci.yaml?logo=github&logoColor=lightgrey
[ci_status_link]: https://github.com/imclerran/roc-tinyparse/actions/workflows/ci.yaml
[last_commit_badge]: https://img.shields.io/github/last-commit/imclerran/roc-tinyparse?logo=git&logoColor=lightgrey
[last_commit_link]: https://github.com/imclerran/roc-tinyparse/commits/main/
[version_badge]: https://img.shields.io/github/v/release/imclerran/roc-tinyparse
[version_link]: https://github.com/imclerran/roc-tinyparse/releases/latest
