import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/task
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

  let #(part1, part2) = solve(input)
  io.println("Part 1: " <> part1)
  io.println("Part 2: " <> part2)
  Ok(Nil)
}

fn solve(input: Input) -> #(String, String) {
  let counts =
    input.designs
    |> list.map(fn(design) {
      task.async(fn() { ways_to_make_design(design, input.patterns) })
    })
    |> list.map(task.await_forever)

  let part1 =
    counts
    |> list.count(fn(count) { count > 0 })
    |> int.to_string()

  let part2 =
    counts
    |> int.sum()
    |> int.to_string()

  #(part1, part2)
}

fn ways_to_make_design(design: String, patterns: List(String)) -> Int {
  let #(result, _memo) = do_ways_to_make_design(design, patterns, dict.new())

  result
}

fn do_ways_to_make_design(
  design: String,
  patterns: List(String),
  memo: dict.Dict(String, Int),
) -> #(Int, dict.Dict(String, Int)) {
  use <- bool.guard(design == "", #(1, memo))
  use <- from_memo(memo, design)

  let #(ways, memo) =
    list.fold(patterns, from: #(0, memo), with: fn(acc, pattern) {
      let #(found, memo) = acc

      use <- bool.guard(!string.starts_with(design, pattern), #(found, memo))

      let #(sub_ways, memo) =
        design
        |> string.drop_start(string.length(pattern))
        |> do_ways_to_make_design(patterns, memo)

      #(sub_ways + found, memo)
    })

  #(ways, dict.insert(memo, design, ways))
}

fn from_memo(
  memo memo: dict.Dict(a, b),
  key key: a,
  then continue: fn() -> #(b, dict.Dict(a, b)),
) -> #(b, dict.Dict(a, b)) {
  case dict.get(memo, key) {
    Ok(val) -> {
      #(val, memo)
    }
    Error(Nil) -> {
      continue()
    }
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
