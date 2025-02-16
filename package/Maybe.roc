module [Maybe, map]

Maybe a : [Some a, None]

map : Maybe a, (a -> b), b -> b
map = |m, f, g|
    when m is
        Some(v) -> f(v)
        None -> g