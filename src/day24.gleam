import argv
import colours
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import simplifile

type Gate {
  XOR(String, String)
  OR(String, String)
  AND(String, String)
  Constant(Int)
}

pub fn main() {
  run_with_input_file()
}

pub fn run_with_input_file() {
  glint.new()
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: ["dot"], do: dot_command())
  |> glint.add(at: [], do: run_command())
  |> glint.run(argv.load().arguments)
}

fn run_command() -> glint.Command(Nil) {
  use filename_arg <- glint.named_arg("filename")
  use solution_arg <- glint.named_arg("solution")
  use <- glint.command_help(
    "Unlike some other solutions, this will not solve your input directly."
    <> " You will need to input your comma separated list of swaps (a,b,c,d will swap a+b and c+d). The program "
    <> " will verify if your solution could be correct."
    <> " The problem can be solved by looking for all of the incorrectly produced full adders. The 'dot' subcommand"
    <> " will produce a graphviz output that can be used to locate these visually."
    <> " If you pass an empty solution to this command (''), you can view the x and y values that are used as."
    <> " inputs. When expressed as binary, these values can be used to locate the incorrect bits, and thus gates",
  )

  use named, _unnamed, _flags <- glint.command()

  let filename = filename_arg(named)
  let solution = solution_arg(named)
  case run_with_file(filename, fn(input_data) { run(input_data, solution) }) {
    Ok(Nil) -> Nil
    Error(err) -> io.println_error(colours.fgmaroon("error") <> ": " <> err)
  }
}

fn dot_command() -> glint.Command(Nil) {
  use filename_arg <- glint.named_arg("filename")
  use named, _unnamed, _flags <- glint.command()

  let filename = filename_arg(named)
  case run_with_file(filename, print_dot) {
    Ok(Nil) -> Nil
    Error(err) -> io.println_error(colours.fgmaroon("error") <> ": " <> err)
  }
}

fn run_with_file(
  filename: String,
  run_func: fn(String) -> Result(Nil, String),
) -> Result(Nil, String) {
  simplifile.read(filename)
  |> result.map_error(simplifile.describe_error)
  |> result.then(run_func)
}

fn run(input: String, solution: String) -> Result(Nil, String) {
  use gates <- result.try(parse_input(input))
  use swaps <- result.try(parse_swaps(solution))

  io.println("Part 1: " <> part1(gates))
  io.println("Part 2: " <> part2(gates, swaps))
  Ok(Nil)
}

fn part1(gates: dict.Dict(String, Gate)) -> String {
  gates
  |> find_gates_with_prefix("z")
  |> list.try_map(fn(output) { resolve_gate(gates, output) })
  |> result.map(fn(outputs) {
    outputs
    |> list.reverse()
    |> list.fold(from: 0, with: fn(acc, bit) { acc * 2 + bit })
    |> int.to_string()
  })
  |> result.unwrap_both()
}

fn part2(
  gates: dict.Dict(String, Gate),
  swaps: List(#(String, String)),
) -> String {
  calculate_part2_inputs_and_output(gates, swaps)
  |> result.map(fn(inputs_and_outputs) {
    let #(#(x_value, y_value), z_value) = inputs_and_outputs

    case x_value + y_value == z_value {
      True -> "Solution is valid for the problem's inputs"
      False ->
        "Solution is NOT valid; x + y != z x="
        <> int.to_string(x_value)
        <> "; y="
        <> int.to_string(y_value)
        <> "; z="
        <> int.to_string(z_value)
    }
  })
  |> result.unwrap_both()
}

fn calculate_part2_inputs_and_output(
  gates: dict.Dict(String, Gate),
  swaps: List(#(String, String)),
) -> Result(#(#(Int, Int), Int), String) {
  let x_gates = find_gates_with_prefix(gates, "x")
  let y_gates = find_gates_with_prefix(gates, "y")
  let z_gates = find_gates_with_prefix(gates, "z")

  let gate_fix_result =
    swaps
    |> list.try_fold(from: gates, with: fn(acc, swap_pair) {
      swap_keys(acc, swap_pair.0, swap_pair.1)
    })
    |> result.map_error(fn(error) { "Could not resolve swaps: " <> error })

  use fixed_gates <- result.try(gate_fix_result)

  use x_value <- result.try(resolve_gates_as_binary(gates, x_gates))
  use y_value <- result.try(resolve_gates_as_binary(gates, y_gates))
  use z_value <- result.try(resolve_gates_as_binary(fixed_gates, z_gates))

  Ok(#(#(x_value, y_value), z_value))
}

fn print_dot(input: String) -> Result(Nil, String) {
  use gates <- result.try(parse_input(input))

  io.println("digraph day24 {")
  let print_binary_gate = fn(left, right, out, kind) {
    let rand_gate_name = int.random(100_000_000) |> int.to_string()
    io.println("  " <> rand_gate_name <> " [label=\"" <> kind <> "\"]")
    io.println("  " <> left <> " -> " <> rand_gate_name)
    io.println("  " <> right <> " -> " <> rand_gate_name)
    io.println("  " <> rand_gate_name <> " -> " <> out)
  }
  dict.each(gates, fn(name, gate) {
    case gate {
      Constant(n) -> {
        io.println(
          "  "
          <> name
          <> " [label=\""
          <> name
          <> "="
          <> int.to_string(n)
          <> "\"];",
        )
      }

      AND(a, b) -> {
        print_binary_gate(a, b, name, "AND")
      }

      XOR(a, b) -> {
        print_binary_gate(a, b, name, "XOR")
      }

      OR(a, b) -> {
        print_binary_gate(a, b, name, "OR")
      }
    }
  })
  io.println("}")

  Ok(Nil)
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

fn resolve_gates_as_binary(
  gates: dict.Dict(String, Gate),
  gates_to_resolve: List(String),
) -> Result(Int, String) {
  gates_to_resolve
  |> list.try_map(fn(gate) { resolve_gate(gates, gate) })
  |> result.map(fn(outputs) {
    outputs
    |> list.reverse()
    |> list.fold(from: 0, with: fn(acc, bit) { acc * 2 + bit })
  })
}

fn find_gates_with_prefix(
  gates: dict.Dict(String, Gate),
  prefix: String,
) -> List(String) {
  gates
  |> dict.keys()
  |> list.filter_map(fn(key) {
    use <- bool.guard(
      when: !string.starts_with(key, prefix),
      return: Error(Nil),
    )

    key
    |> string.drop_start(string.length(prefix))
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

fn parse_swaps(solution: String) -> Result(List(#(String, String)), String) {
  use <- bool.guard(solution == "", Ok([]))

  solution
  |> string.split(",")
  |> list.sized_chunk(2)
  |> list.try_map(fn(chunk) {
    case chunk {
      [a, b] -> Ok(#(a, b))
      _ -> Error("Solution must contain an even number of wires to swap")
    }
  })
}

fn swap_keys(
  dict: dict.Dict(a, b),
  key1: a,
  key2: a,
) -> Result(dict.Dict(a, b), String) {
  case dict.get(dict, key1), dict.get(dict, key2) {
    Ok(value1), Ok(value2) -> {
      dict
      |> dict.insert(key2, value1)
      |> dict.insert(key1, value2)
      |> Ok()
    }

    Error(Nil), _ -> Error("Key not found " <> string.inspect(key1))
    _, Error(Nil) -> Error("Key not found " <> string.inspect(key2))
  }
}
