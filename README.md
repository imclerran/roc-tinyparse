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

expect
    parser = rhs(maybe(string("v")), zip_3(integer, rhs(dot, integer), rhs(dot, integer)))
    parser("v1.2.34_abc") |> finalize_lazy == Ok((1, 2, 34))
```
```roc
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

semver = rhs(maybe(string("v")), zip_3(major, minor, patch))

expect semver("v1.2.34_abc") |> finalize_lazy == Ok((Major(1), Minor(2), Patch(34)))
expect semver("123") |> finalize_lazy == Ok((Major(123), NoMinor, NoPatch))
```

## Semver in < 60 lines
```roc
valid_semver = zip_3(version_core, maybe(rhs(hyphen, pre_release)), maybe(rhs(plus, build)))

plus = char |> filter(|c| c == '+')

version_core = zip_3(major, rhs(dot, minor), rhs(dot, patch))

major = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

minor = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

patch = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

pre_release = dot_separated_pre_release_identifiers

dot_separated_pre_release_identifiers =
    both(pre_release_identifier, zero_or_more(rhs(dot, pre_release_identifier)))
    |> map(|(id, ids)| Ok(List.join([[id], ids])))

build = dot_separated_build_identifiers

dot_separated_build_identifiers =
    both(build_identifier, zero_or_more(rhs(dot, build_identifier)))
    |> map(|(id, ids)| Ok(List.join([[id], ids])))

dot = char |> filter(|c| c == '.')

pre_release_identifier = alphanumeric_identifier |> or_else(numeric_identifier)

build_identifier = alphanumeric_identifier |> or_else(digits)

alphanumeric_identifier =
    is_non_digit = |c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '-'
    contains_non_digit = |cs| List.walk_until(cs, Bool.false, |_, c| if is_non_digit(c) then Break(Bool.true) else Continue(Bool.false))
    identifier_characters
    |> filter(|cs| contains_non_digit(cs))

numeric_identifier =
    (zero |> map(|c| Ok([c])))
    |> or_else(both(positive_digit, digits) |> map(|(c, cs)| Ok(List.join([[c], cs]))))
    |> or_else(positive_digit |> map(|c| Ok([c])))

identifier_characters = one_or_more(identifier_character)

identifier_character = digit |> or_else(non_digit)

non_digit = letter |> or_else(hyphen)

hyphen = char |> filter(|c| c == '-')

digits = one_or_more(digit)

digit = zero |> or_else(positive_digit)

zero = char |> filter(|c| c == '0')

positive_digit = char |> filter(|c| c >= '1' and c <= '9')

letter = char |> filter(|c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z'))
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
