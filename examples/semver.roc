app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    parse: "../package/main.roc",
}

import cli.Stdout
import parse.Parse exposing [char, filter, one_or_more, both, or_else, map, zip_3, rhs, zero_or_more, maybe, finalize_lazy]

semvers = [
    "0.0.1",
    "1.9.0",
    "1.10.0",
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0-0.3.7",
    "1.0.0-x.7.z.92",
    "1.0.0-x-y-z.--",
    "1.0.0-alpha+001",
    "1.0.0+20130313144700",
    "1.0.0-beta+exp.sha.5114f85",
    "1.0.0+21AF26D3----117B344092BD",
]

main! = |_args|
    List.for_each_try!(
        semvers,
        |semver_str|
            when parse_semver(semver_str) is
                Ok(semver) -> 
                    Stdout.line!(semver_str)?
                    Stdout.line!("------------------------------")?
                    print_semver!(semver)?
                    Stdout.line!("")
                Err(InvalidSemver) -> 
                    Stdout.line!("Invalid SemVer: ${semver_str}\n"),
    )
    # when args is
    #     [_, arg1, ..] ->
    #         semver_str = Arg.display(arg1)
    #         when parse_semver(semver_str) is
    #             Ok(semver) -> print_semver!(semver)
    #             Err(InvalidSemver) -> Stdout.line!("Invalid SemVer: ${semver_str}")

    #     [bin] -> Stdout.line!("Usage: ${Arg.display(bin)} <version>")
    #     [] -> Stdout.line!("Usage: semver <version>")

print_semver! = |semver|
    Stdout.line!("Major: ${semver.major |> Num.to_str}")?
    Stdout.line!("Minor: ${semver.minor |> Num.to_str}")?
    Stdout.line!("Patch: ${semver.patch |> Num.to_str}")?
    when semver.pre_release is
        [] -> Stdout.line!("No pre-release")?
        ps -> Stdout.line!("Pre-release: ${Str.join_with(ps, ".")}")?
    when semver.build is
        [] -> Stdout.line!("No build")
        bs -> Stdout.line!("Build: ${Str.join_with(bs, ".")}")

map_maybe = |m, f, g|
    when m is
        Some(v) -> f(v)
        None -> g

parse_semver = |str|
    parser =
        valid_semver
        |> map(
            |(core, maybe_pre_release, maybe_build)|
                Ok(
                    {
                        major: core.0,
                        minor: core.1,
                        patch: core.2,
                        pre_release: map_maybe(maybe_pre_release, |ids| List.map(ids, Str.from_utf8_lossy), []),
                        build: map_maybe(maybe_build, |ids| List.map(ids, Str.from_utf8_lossy), []),
                        # build: map_maybe(maybe_build_cs, |cs| Build(Str.from_utf8_lossy(cs)), NoBuild),
                    },
                ),
        )
    parser(str) |> finalize_lazy |> Result.map_err(|_| InvalidSemver)

## ```
## <valid semver> ::= <version core>
##                  | <version core> "-" <pre-release>
##                  | <version core> "+" <build>
##                  | <version core> "-" <pre-release> "+" <build>
## ```
valid_semver = zip_3(version_core, maybe(rhs(hyphen, pre_release)), maybe(rhs(plus, build)))

## ```
## <plus> ::= "+"
## ```
plus = char |> filter(|c| c == '+')

## ```
## <version core> ::= <major> "." <minor> "." <patch>
## ```
version_core = zip_3(major, rhs(dot, minor), rhs(dot, patch))

## ```
## <major> ::= <numeric identifier>
# ```
major = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

## ```
## <minor> ::= <numeric identifier>
## ```
minor = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

## ```
## <patch> ::= <numeric identifier>
## ```
patch = numeric_identifier |> map(|id| Str.from_utf8_lossy(id) |> Str.to_u64)

## ```
## <pre-release> ::= <dot-separated pre-release identifiers>
## ```
pre_release = dot_separated_pre_release_identifiers

## ```
## <dot-separated pre-release identifiers> ::= <pre-release identifier>
##                                           | <pre-release identifier> "." <dot-separated pre-release identifiers>
## ```
dot_separated_pre_release_identifiers =
    pre_release_identifier
    |> both(zero_or_more(rhs(dot, pre_release_identifier)))
    |> map(|(id, ids)| Ok(List.join([[id], ids])))

## ```
## <build> ::= <dot-separated build identifiers>
## ```
build = dot_separated_build_identifiers

## ```
## <dot-separated build identifiers> ::= <build identifier>
##                                     | <build identifier> "." <dot-separated build identifiers>
## ```
dot_separated_build_identifiers =
    build_identifier
    |> both(zero_or_more(rhs(dot, build_identifier)))
    |> map(|(id, ids)| Ok(List.join([[id], ids])))

## ```
## <dot> ::= "."
## ```
dot = char |> filter(|c| c == '.')

## ```
# <pre-release identifier> ::= <alphanumeric identifier>
#                            | <numeric identifier>
# ```
pre_release_identifier = alphanumeric_identifier |> or_else(numeric_identifier)

## ```
## <build identifier> ::= <alphanumeric identifier>
##                      | <digits>
## ```
build_identifier = alphanumeric_identifier |> or_else(digits)

## ```
## <alphanumeric identifier> ::= <non-digit>
##                             | <non-digit> <identifier characters>
##                             | <identifier characters> <non-digit>
##                             | <identifier characters> <non-digit> <identifier characters>
## ```
alphanumeric_identifier =
    is_non_digit = |c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '-'
    contains_non_digit = |cs| List.walk_until(cs, Bool.false, |_, c| if is_non_digit(c) then Break(Bool.true) else Continue(Bool.false))
    identifier_characters
    |> filter(|cs| contains_non_digit(cs))

## ```
## <numeric identifier> ::= <zero>
##                        | <positive digit>
##                        | <positive digit> <digits>
## ```
numeric_identifier =
    zero
    |> map(|c| Ok([c]))
    |> or_else(positive_digit |> map(|c| Ok([c])))
    |> or_else(both(positive_digit, digits) |> map(|(c, cs)| Ok(List.join([[c], cs]))))

## ```
## <identifier characters> ::= <identifier character>
##                           | <identifier character> <identifier characters>
## ```
identifier_characters = one_or_more(identifier_character)

## ```
## <identifier character> ::= <digit>
##                          | <non-digit>
## ```
identifier_character = digit |> or_else(non_digit)

## ```
## <non-digit> ::= <letter>
##               | <hyphen>
## ```
non_digit = letter |> or_else(hyphen)

## ```
## <hyphen> ::= "-"
## ```
hyphen = char |> filter(|c| c == '-')

## ```
## <digits> ::= <digit>
##            | <digit> <digits>
## ```
digits = one_or_more(digit)

## ```
## <digit> ::= <zero> | <positive digit>
## ```
digit = zero |> or_else(positive_digit)

## ```
## <zero> ::= "0"
## ```
zero = char |> filter(|c| c == '0')

## ```
## <positive digit> ::= "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
## ```
positive_digit = char |> filter(|c| c >= '1' and c <= '9')

## ```
## <letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
##            | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T"
##            | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d"
##            | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n"
##            | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
##            | "y" | "z"
## ```
letter = char |> filter(|c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z'))
