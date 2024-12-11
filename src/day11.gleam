import advent_of_code_2024
import gleam/bool
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(input))

  Ok(Nil)
}

fn part1(input: List(Int)) -> String {
  list.range(from: 1, to: 25)
  |> list.fold(from: input, with: fn(stones, _n) { simulate(stones) })
  |> list.length()
  |> int.to_string()
}

fn simulate(stones: List(Int)) {
  do_simulate(stones, [])
}

fn do_simulate(in_stones: List(Int), out_stones: List(Int)) {
  case in_stones {
    [] -> list.reverse(out_stones)
    [stone, ..rest_stones] -> {
      let out_stones =
        stone
        |> transform_stone()
        |> list.fold(from: out_stones, with: list.prepend)

      do_simulate(rest_stones, out_stones)
    }
  }
}

fn transform_stone(stone: Int) -> List(Int) {
  use <- bool.guard(when: stone == 0, return: [1])
  let num_digits = num_digits(stone)
  use <- bool.guard(when: num_digits % 2 == 1, return: [stone * 2024])
  let divisor = int_pow(10, num_digits / 2)
  let upper_digits = stone / divisor
  let lower_digits = stone % divisor

  [upper_digits, lower_digits]
}

fn parse_input(input: String) -> Result(List(Int), String) {
  input
  |> string.trim_end()
  |> string.split(" ")
  |> list.try_map(parse_int)
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Invalid integer " <> s })
}

fn int_pow(base: Int, power: Int) -> Int {
  case power {
    0 -> 1
    1 -> base
    power -> base * int_pow(base, power - 1)
  }
}

fn num_digits(n: Int) -> Int {
  use <- bool.guard(when: n == 0, return: 1)

  let result =
    n
    |> int.absolute_value
    |> log_10()
    |> float.truncate

  result + 1
}

@external(erlang, "math", "log10")
fn log_10(n: Int) -> Float
