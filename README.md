# roc-tinyparse
A small parser combinator library for roc.


## Example
```roc
expect 
    parser = string("Hello")
    parser("Hello, world!") == Ok(("Hello", ", world!"))

expect
    parser = string("Hello")
    parser("Hello, world!") |> finalize == Ok("Hello")

expect
    parser = string("Hello") |> lhs(comma) |> lhs(whitespace) |> both(string("world")) 
    parser("Hello, world!") |> finalize == Ok(("Hello", "world"))
```