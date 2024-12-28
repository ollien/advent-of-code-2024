import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Gate {
  XOR(String, String)
  OR(String, String)
  AND(String, String)
  Constant(Int)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use gates <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(gates))
  Ok(Nil)
}

fn part1(gates: dict.Dict(String, Gate)) -> String {
  gates
  |> find_output_gates()
  |> list.try_map(fn(output) { resolve_gate(gates, output) })
  |> result.map(fn(outputs) {
    outputs
    |> list.reverse()
    |> list.fold(from: 0, with: fn(acc, bit) { acc * 2 + bit })
    |> int.to_string()
  })
  |> result.unwrap_both()
}

fn resolve_gate(
  gates: dict.Dict(String, Gate),
  start: String,
) -> Result(Int, String) {
  use gate <- result.try(
    dict.get(gates, start)
    |> result.map_error(fn(_nil) { "Invalid gate " <> start }),
  )

  case gate {
    Constant(value) -> Ok(value)
    XOR(left_name, right_name) -> {
      use left <- result.try(resolve_gate(gates, left_name))
      use right <- result.try(resolve_gate(gates, right_name))

      Ok(int.bitwise_exclusive_or(left, right))
    }

    OR(left_name, right_name) -> {
      use left <- result.try(resolve_gate(gates, left_name))
      use right <- result.try(resolve_gate(gates, right_name))

      Ok(int.bitwise_or(left, right))
    }

    AND(left_name, right_name) -> {
      use left <- result.try(resolve_gate(gates, left_name))
      use right <- result.try(resolve_gate(gates, right_name))

      Ok(int.bitwise_and(left, right))
    }
  }
}

fn find_output_gates(gates: dict.Dict(String, Gate)) -> List(String) {
  gates
  |> dict.keys()
  |> list.filter_map(fn(key) {
    use <- bool.guard(when: !string.starts_with(key, "z"), return: Error(Nil))

    key
    |> string.drop_start(1)
    |> int.parse()
    |> result.map(fn(parsed) { #(key, parsed) })
  })
  |> list.sort(fn(a, b) { int.compare(a.1, b.1) })
  |> list.map(fn(pair) { pair.0 })
}

fn parse_input(input: String) -> Result(dict.Dict(String, Gate), String) {
  let chunks =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  case chunks {
    [constants, gates] -> {
      use parsed_constants <- result.try(parse_chunk(constants, parse_constant))
      use parsed_gates <- result.try(parse_chunk(gates, parse_gate_line))

      Ok(dict.merge(parsed_constants, parsed_gates))
    }
    _ -> Error("Input must have exactly two chunks")
  }
}

fn parse_chunk(
  input: String,
  parser: fn(String) -> Result(#(String, Gate), String),
) -> Result(dict.Dict(String, Gate), String) {
  input
  |> string.split("\n")
  |> list.try_map(parser)
  |> result.map(dict.from_list)
}

fn parse_gate_line(line: String) {
  case string.split(line, " -> ") {
    [gate, output_name] -> {
      use gate <- result.try(parse_gate(gate))

      Ok(#(output_name, gate))
    }
    _ -> Error("Malformed gate line " <> line)
  }
}

fn parse_gate(gate: String) -> Result(Gate, String) {
  case string.split(gate, " ") {
    [left, "AND", right] -> Ok(AND(left, right))
    [left, "XOR", right] -> Ok(XOR(left, right))
    [left, "OR", right] -> Ok(OR(left, right))
    _ -> Error("Malformed gate " <> gate)
  }
}

fn parse_constant(line: String) -> Result(#(String, Gate), String) {
  case string.split(line, ": ") {
    [name, raw_value] -> {
      use value <- result.try(parse_int(raw_value))

      Ok(#(name, Constant(value)))
    }
    _ -> Error("Malformed constant line " <> line)
  }
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Malformed int " <> s })
}
