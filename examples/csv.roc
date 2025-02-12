app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    parse: "../package/main.roc",
}

import "packages.csv" as csv : Str

import cli.Stdout
import parse.Parse exposing [both, lhs, rhs, string, maybe, map, one_or_more, finalize]
import parse.CSV exposing [csv_string]

main! = |_|
    parse_csv(csv)?
    |> List.for_each_try!(
        |{ repo, alias }|
            Stdout.line!("repo: ${repo} | alias: ${alias}"),
    )

parse_csv = |csv_text|
    parser = maybe(parse_csv_header) |> rhs(one_or_more(parse_csv_line))
    parser(csv_text) |> Result.map_err(|_| InvalidCSV) |> finalize

parse_csv_header = |str|
    parser = string("repo,alias") |> lhs(maybe(string(","))) |> lhs(string("\n"))
    parser(str) |> Result.map_err(|_| InvalidCSVHeader)

parse_csv_line = |str|
    parser =
        csv_string
        |> lhs(string(","))
        |> both(csv_string)
        |> lhs(maybe(string(",")))
        |> lhs(maybe(string("\n")))
        |> map(|(repo, alias)| Ok({ repo, alias }))
    parser(str) |> Result.map_err(|_| InvalidCSVLine)
