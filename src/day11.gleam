import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(input))
  io.println("Part 2: " <> part2(input))

  Ok(Nil)
}

fn part1(input: dict.Dict(Int, Int)) -> String {
  input
  |> run_simulation(25)
  |> int.to_string()
}

fn part2(input: dict.Dict(Int, Int)) -> String {
  input
  |> run_simulation(75)
  |> int.to_string()
}

fn run_simulation(input: dict.Dict(Int, Int), num_steps: Int) -> Int {
  list.range(from: 1, to: num_steps)
  |> list.fold(from: input, with: fn(stones, _n) { simulate_step(stones) })
  |> dict.values()
  |> int.sum()
}

fn simulate_step(stones: dict.Dict(Int, Int)) -> dict.Dict(Int, Int) {
  do_simulate_step(dict.to_list(stones), [])
}

fn do_simulate_step(
  in_stones: List(#(Int, Int)),
  out_stones: List(#(Int, Int)),
) -> dict.Dict(Int, Int) {
  case in_stones {
    [] ->
      list.fold(out_stones, from: dict.new(), with: fn(acc, entry) {
        let #(key, count) = entry
        dict.upsert(acc, key, fn(current) {
          case current {
            option.None -> count
            option.Some(n) -> n + count
          }
        })
      })

    [#(stone, count), ..rest_stones] -> {
      let out_stones = case transform_stone(stone) {
        [new_stone] -> [#(new_stone, count), ..out_stones]
        [new_stone1, new_stone2] -> [
          #(new_stone1, count),
          #(new_stone2, count),
          ..out_stones
        ]
        _ ->
          panic as "it is not possible to have more than two stones produced by a single one in this simulation"
      }

      do_simulate_step(rest_stones, out_stones)
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

fn parse_input(input: String) -> Result(dict.Dict(Int, Int), String) {
  input
  |> string.trim_end()
  |> string.split(" ")
  |> list.try_map(parse_int)
  |> result.map(fn(stones) {
    list.fold(stones, from: dict.new(), with: fn(acc, stone) {
      dict.upsert(acc, stone, fn(count) {
        case count {
          option.Some(n) -> n + 1
          option.None -> 1
        }
      })
    })
  })
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
