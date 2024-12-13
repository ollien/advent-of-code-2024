import advent_of_code_2024
import gleam/bool
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

type Machine {
  Machine(button_a: Button, button_b: Button, prize: Prize)
}

type Button {
  Button(x: Int, y: Int)
}

type Prize {
  Prize(x: Int, y: Int)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use machines <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(machines))
  io.println("Part 2: " <> part2(machines))

  Ok(Nil)
}

fn part1(machines: List(Machine)) -> String {
  solve(machines)
}

fn part2(machines: List(Machine)) -> String {
  machines
  |> list.map(fn(machine) {
    let upd_prize =
      Prize(
        x: machine.prize.x + 10_000_000_000_000,
        y: machine.prize.y + 10_000_000_000_000,
      )

    Machine(..machine, prize: upd_prize)
  })
  |> solve()
}

fn solve(machines: List(Machine)) -> String {
  machines
  |> list.filter_map(solve_machine)
  |> int.sum()
  |> int.to_string()
}

fn solve_machine(machine: Machine) -> Result(Int, Nil) {
  use <- bool.guard(
    machine.button_a.x * machine.button_b.y
      == machine.button_a.y * machine.button_b.x,
    return: Error(Nil),
  )

  let a_x = int.to_float(machine.button_a.x)
  let a_y = int.to_float(machine.button_a.y)
  let b_x = int.to_float(machine.button_b.x)
  let b_y = int.to_float(machine.button_b.y)
  let prize_x = int.to_float(machine.prize.x)
  let prize_y = int.to_float(machine.prize.y)

  // Solved algebraically from
  // prize_x = a_x * A + b_x * B
  // prize_y = a_y * A + b_y * B
  let a_clicks =
    { prize_y *. b_x -. prize_x *. b_y } /. { a_y *. b_x -. a_x *. b_y }

  let b_clicks =
    { prize_y *. a_x -. prize_x *. a_y } /. { a_x *. b_y -. a_y *. b_x }

  case
    float.loosely_equals(a_clicks, float.floor(a_clicks), tolerating: 0.0001)
    && float.loosely_equals(b_clicks, float.floor(b_clicks), tolerating: 0.0001)
  {
    True -> Ok(3 * float.truncate(a_clicks) + float.truncate(b_clicks))
    False -> Error(Nil)
  }
}

fn parse_input(input: String) -> Result(List(Machine), String) {
  input
  |> string.trim_end()
  |> string.split("\n\n")
  |> list.try_map(parse_machine)
}

fn parse_machine(input_chunk: String) -> Result(Machine, String) {
  case string.split(input_chunk, "\n") {
    [line1, line2, line3] -> {
      use button_a <- result.try(parse_button(line1, "A"))
      use button_b <- result.try(parse_button(line2, "B"))
      use prize <- result.try(parse_prize(line3))

      Ok(Machine(button_a:, button_b:, prize:))
    }

    _ -> Error("Malformed input; chunk must have exactly three lines")
  }
}

fn parse_button(line: String, label: String) -> Result(Button, String) {
  let assert Ok(pattern) =
    regexp.compile(
      "^Button ([A-Z]): X\\+(\\d+), Y\\+(\\d+)$",
      with: regexp.Options(case_insensitive: False, multi_line: False),
    )
  case regexp.scan(pattern, line) {
    [
      regexp.Match(
        submatches: [
          option.Some(label_match),
          option.Some(x_match),
          option.Some(y_match),
        ],
        ..,
      ),
    ]
      if label_match == label
    -> {
      // These must be valid by our pattern
      let assert Ok(x) = int.parse(x_match)
      let assert Ok(y) = int.parse(y_match)

      Ok(Button(x:, y:))
    }
    [_wrong_match] | [] -> Error("Malformed input line " <> line)
    _ -> panic as "not possible to have more than one match"
  }
}

fn parse_prize(line: String) -> Result(Prize, String) {
  let assert Ok(pattern) =
    regexp.compile(
      "^Prize: X=(\\d+), Y=(\\d+)$",
      with: regexp.Options(case_insensitive: False, multi_line: False),
    )
  case regexp.scan(pattern, line) {
    [regexp.Match(submatches: [option.Some(x_match), option.Some(y_match)], ..)] -> {
      // These must be valid by our pattern
      let assert Ok(x) = int.parse(x_match)
      let assert Ok(y) = int.parse(y_match)

      Ok(Prize(x:, y:))
    }
    [_wrong_match] | [] -> Error("Malformed input line " <> line)
    _ -> panic as "not possible to have more than one match"
  }
}
