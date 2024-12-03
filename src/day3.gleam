import advent_of_code_2024
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type ParseError {
  ParseError
}

type ParseOutput(a) {
  ParseOutput(parsed: a, rest: String)
}

type Instruction {
  MulInstruction(Int, Int)
  DoInstruction
  DontInstruction
}

type ProgramState {
  ProgramState(enabled: InstructionsEnabled, total: Int)
}

type InstructionsEnabled {
  Enabled
  Disabled
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  let instructions = parse_instructions(input)
  io.println("Part 1: " <> part1(instructions))
  io.println("Part 2: " <> part2(instructions))
  Ok(Nil)
}

fn part1(instructions: List(Instruction)) -> String {
  instructions
  |> list.filter(is_mul_instruction)
  |> evaluate_instructions()
  |> int.to_string()
}

fn part2(instructions: List(Instruction)) -> String {
  instructions
  |> evaluate_instructions()
  |> int.to_string()
}

fn is_mul_instruction(instruction: Instruction) -> Bool {
  case instruction {
    MulInstruction(_left, _right) -> True
    _ -> False
  }
}

fn evaluate_instructions(instructions: List(Instruction)) -> Int {
  let state =
    list.fold(
      instructions,
      from: ProgramState(enabled: Enabled, total: 0),
      with: try_evaluate_instruction,
    )

  state.total
}

fn try_evaluate_instruction(
  state: ProgramState,
  instruction: Instruction,
) -> ProgramState {
  case state.enabled, instruction {
    _state, DoInstruction -> ProgramState(..state, enabled: Enabled)
    Disabled, _any -> state
    Enabled, DontInstruction -> ProgramState(..state, enabled: Disabled)
    Enabled, MulInstruction(left, right) ->
      ProgramState(..state, total: state.total + left * right)
  }
}

fn parse_instructions(input: String) -> List(Instruction) {
  // Did I need a recursive descent parser? no, but it was for fun :)
  do_parse_instructions(input, [])
}

fn do_parse_instructions(
  input: String,
  acc: List(Instruction),
) -> List(Instruction) {
  use <- bool.lazy_guard(when: string.is_empty(input), return: fn() {
    list.reverse(acc)
  })

  case parse_next_instruction(input) {
    Ok(output) -> do_parse_instructions(output.rest, [output.parsed, ..acc])
    Error(ParseError) -> {
      // This is much faster than drop_start(1)
      let #(_head, rest) =
        string.pop_grapheme(input) |> result.unwrap(or: #("", ""))
      do_parse_instructions(rest, acc)
    }
  }
}

fn parse_next_instruction(
  input: String,
) -> Result(ParseOutput(Instruction), ParseError) {
  use <- result.lazy_or(parse_do_instruction(input))
  use <- result.lazy_or(parse_dont_instruction(input))

  parse_mul_instruction(input)
}

fn parse_do_instruction(
  input: String,
) -> Result(ParseOutput(Instruction), ParseError) {
  input
  |> parse_prefix(prefix: "do()")
  |> map_parse_output_result(fn(_ignore) { DoInstruction })
}

fn parse_dont_instruction(
  input: String,
) -> Result(ParseOutput(Instruction), ParseError) {
  input
  |> parse_prefix(prefix: "don't()")
  |> map_parse_output_result(fn(_ignore) { DontInstruction })
}

fn parse_mul_instruction(
  input: String,
) -> Result(ParseOutput(Instruction), ParseError) {
  use prefix_output <- result.try(parse_prefix(in: input, prefix: "mul("))

  prefix_output.rest
  |> parse_operands()
  |> map_parse_output_result(fn(operands) {
    MulInstruction(operands.0, operands.1)
  })
  |> result.map(fn(output) {
    finish_with(output, parse_prefix(in: output.rest, prefix: ")"))
  })
  |> result.flatten
}

fn map_parse_output_result(
  result: Result(ParseOutput(a), c),
  func: fn(a) -> b,
) -> Result(ParseOutput(b), c) {
  result.map(result, fn(output) { map_parse_output(output, func) })
}

fn map_parse_output(output: ParseOutput(a), func: fn(a) -> b) -> ParseOutput(b) {
  ParseOutput(parsed: func(output.parsed), rest: output.rest)
}

fn parse_operands(input: String) -> Result(ParseOutput(#(Int, Int)), ParseError) {
  use left_output <- result.try(parse_int(input))
  use comma_output <- result.try(parse_prefix(in: left_output.rest, prefix: ","))
  use right_output <- result.try(parse_int(comma_output.rest))

  Ok(ParseOutput(
    parsed: #(left_output.parsed, right_output.parsed),
    rest: right_output.rest,
  ))
}

fn finish_with(
  output: ParseOutput(a),
  and final_result: Result(ParseOutput(b), ParseError),
) -> Result(ParseOutput(a), ParseError) {
  map_parse_output_result(final_result, fn(_ignore) { output.parsed })
}

fn parse_prefix(
  in input: String,
  prefix prefix: String,
) -> Result(ParseOutput(String), ParseError) {
  case string.starts_with(input, prefix) {
    False -> Error(ParseError)
    True -> {
      let rest = string.drop_start(input, string.length(prefix))
      Ok(ParseOutput(parsed: prefix, rest:))
    }
  }
}

fn parse_int(input: String) -> Result(ParseOutput(Int), ParseError) {
  let digits = take_digits(input)
  digits
  |> int.parse
  |> result.map(fn(parsed) {
    let digit_length = string.length(digits)
    let rest = string.drop_start(input, digit_length)

    ParseOutput(parsed:, rest:)
  })
  |> result.map_error(fn(_nil) { ParseError })
}

fn take_digits(input: String) -> String {
  case string.pop_grapheme(input) {
    Error(Nil) -> ""
    Ok(#(first_char, rest)) -> {
      use <- bool.guard(when: !is_digit(first_char), return: "")

      first_char <> take_digits(rest)
    }
  }
}

fn is_digit(input: String) -> Bool {
  case input {
    "0" -> True
    "1" -> True
    "2" -> True
    "3" -> True
    "4" -> True
    "5" -> True
    "6" -> True
    "7" -> True
    "8" -> True
    "9" -> True
    _ -> False
  }
}
