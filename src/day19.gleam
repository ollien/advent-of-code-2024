import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Input {
  Input(patterns: List(String), designs: List(String))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(input))
  Ok(Nil)
}

fn part1(input: Input) -> String {
  input.designs
  |> list.count(fn(design) { can_make_design(design, input.patterns) })
  |> int.to_string()
}

fn can_make_design(design: String, patterns: List(String)) -> Bool {
  let #(result, _memo) = do_can_make_design(design, patterns, dict.new())

  result
}

fn do_can_make_design(
  design: String,
  patterns: List(String),
  memo: dict.Dict(String, Bool),
) -> #(Bool, dict.Dict(String, Bool)) {
  use <- bool.guard(design == "", #(True, memo))
  use <- from_memo(memo, design)

  let #(found, memo) =
    list.fold_until(patterns, from: #(False, memo), with: fn(acc, pattern) {
      let #(_found, memo) = acc

      use <- bool.guard(
        !string.starts_with(design, pattern),
        list.Continue(#(False, memo)),
      )

      let #(res, memo) =
        design
        |> string.drop_start(string.length(pattern))
        |> do_can_make_design(patterns, memo)

      case res {
        True -> list.Stop(#(True, memo))
        False -> list.Continue(#(False, memo))
      }
    })

  #(found, dict.insert(memo, design, found))
}

fn from_memo(
  memo memo: dict.Dict(a, b),
  key key: a,
  then continue: fn() -> #(b, dict.Dict(a, b)),
) -> #(b, dict.Dict(a, b)) {
  case dict.get(memo, key) {
    Ok(val) -> #(val, memo)
    Error(Nil) -> continue()
  }
}

fn parse_input(input: String) -> Result(Input, String) {
  let chunks =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  case chunks {
    [pattern_chunk, design_chunk] -> {
      Ok(Input(
        patterns: parse_patterns(pattern_chunk),
        designs: parse_designs(design_chunk),
      ))
    }
    _ -> Error("Input must have two chunks")
  }
}

fn parse_patterns(s: String) -> List(String) {
  string.split(s, ", ")
}

fn parse_designs(s: String) -> List(String) {
  string.split(s, "\n")
}
