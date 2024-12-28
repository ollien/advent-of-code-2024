import advent_of_code_2024
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use numbers <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(numbers))
  Ok(Nil)
}

fn part1(numbers: List(Int)) -> String {
  numbers
  |> list.map(fn(number) { nth_number(number, 2000) })
  |> int.sum()
  |> int.to_string()
}

fn nth_number(init num: Int, times n: Int) -> Int {
  list.fold(list.range(from: 0, to: n - 1), from: num, with: fn(acc, _nth) {
    next_n(acc)
  })
}

fn next_n(n: Int) -> Int {
  let n = n |> mix(n * 64) |> prune()
  let n = n |> mix(n / 32) |> prune()
  let n = n |> mix(n * 2048) |> prune()

  n
}

fn mix(a: Int, b: Int) -> Int {
  int.bitwise_exclusive_or(a, b)
}

fn prune(n: Int) -> Int {
  n % 16_777_216
}

fn parse_input(input: String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_int)
}

fn parse_int(n: String) -> Result(Int, String) {
  case int.parse(n) {
    Ok(res) -> Ok(res)
    Error(Nil) -> Error("Invalid integer " <> n)
  }
}
