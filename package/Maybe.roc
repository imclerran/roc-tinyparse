module [Maybe, map]

Maybe a : [Some a, None]

## Transform a Maybe value.
## ```
## expect Some(1) |> map(Number, Nothing) == Number(1)
## expect None |> map(Number, Nothing) == Nothing
## ```
map : Maybe a, (a -> b), b -> b
map = |m, f, g|
    when m is
        Some(v) -> f(v)
        None -> g