import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string

type Registers {
  Registers(pc: Int, a: Int, b: Int, c: Int)
}

type Program {
  Program(instructions: dict.Dict(Int, Instruction))
}

type Instruction {
  ADVInstruction(operand: ComboOperand)
  BXLInstruction(operand: LiteralOperand)
  BSTInstruction(operand: ComboOperand)
  JNZInstruction(operand: LiteralOperand)
  BXCInstruction
  OutInstruction(operand: ComboOperand)
  BDVInstruction(operand: ComboOperand)
  CDVInstruction(operand: ComboOperand)
}

type LiteralOperand {
  LiteralOperand(value: Int)
}

type ComboOperand {
  LiteralComboOperand(value: Int)
  RegisterAComboOperand
  RegisterBComboOperand
  RegisterCComboOperand
}

type InstructionResult {
  InstructionResult(registers: Registers, output: option.Option(Int))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use #(registers, #(raw_program, program)) <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(registers, program))
  io.println("Part 2: " <> part2(raw_program))

  Ok(Nil)
}

fn part1(registers: Registers, program: Program) -> String {
  let outputs = run_program(registers, program)

  outputs
  |> list.map(int.to_string)
  |> string.join(",")
}

fn part2(raw_program: List(Int)) -> String {
  let assert Ok(n) = do_part_2(1, list.reverse(raw_program), [])

  n
  |> int.to_string()
}

fn do_part_2(
  init: Int,
  needed: List(Int),
  acquired: List(Int),
) -> Result(Int, Nil) {
  use need_now, need_later <- try_pop(needed, Ok(init / 8))

  do_part_2_step(init, init + 8, need_now, acquired, fn(n) {
    do_part_2(n * 8, need_later, [calculate_b(n) % 8, ..acquired])
  })
}

fn do_part_2_step(
  n: Int,
  max: Int,
  needed: Int,
  acquired: List(Int),
  continue: fn(Int) -> Result(Int, Nil),
) -> Result(Int, Nil) {
  use <- bool.guard(n > max, Error(Nil))

  let result = calculate_b(n) % 8
  use <- bool.lazy_guard(
    result != needed || my_program(n) != [result, ..acquired],
    fn() { do_part_2_step(n + 1, max, needed, acquired, continue) },
  )

  case continue(n) {
    Error(Nil) -> {
      do_part_2_step(n + 1, max, needed, acquired, continue)
    }
    Ok(found) -> Ok(found)
  }
}

fn my_program(a: Int) -> List(Int) {
  a
  |> do_my_program([])
  |> list.reverse()
}

fn do_my_program(a: Int, out: List(Int)) -> List(Int) {
  let b = calculate_b(a)

  case a / 8 {
    0 -> [b % 8, ..out]
    n -> do_my_program(n, [b % 8, ..out])
  }
}

// This, and my_program, are specialized to my input
fn calculate_b(a: Int) -> Int {
  let b = a % 8
  let b = int.bitwise_exclusive_or(b, 7)
  let c = a / int_pow(2, b)
  let b = int.bitwise_exclusive_or(b, 7)
  let b = int.bitwise_exclusive_or(b, c)

  b
}

fn run_program(registers: Registers, program: Program) -> List(Int) {
  do_run_program(registers, program, [])
  |> list.reverse()
}

fn do_run_program(
  registers: Registers,
  program: Program,
  output_acc: List(Int),
) -> List(Int) {
  case dict.get(program.instructions, registers.pc) {
    Ok(instruction) -> {
      let instruction_result = run_instruction(registers, instruction)
      let output_acc =
        instruction_result.output
        |> option.map(fn(value) { [value, ..output_acc] })
        |> option.unwrap(or: output_acc)

      do_run_program(instruction_result.registers, program, output_acc)
    }

    Error(Nil) -> output_acc
  }
}

fn run_instruction(
  registers: Registers,
  instruction: Instruction,
) -> InstructionResult {
  case instruction {
    ADVInstruction(operand) -> {
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          a: evaluate_div_instruction(registers, operand),
        ),
        output: option.None,
      )
    }

    BDVInstruction(operand) -> {
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          b: evaluate_div_instruction(registers, operand),
        ),
        output: option.None,
      )
    }

    CDVInstruction(operand) -> {
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          c: evaluate_div_instruction(registers, operand),
        ),
        output: option.None,
      )
    }

    BXLInstruction(operand) -> {
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          b: int.bitwise_exclusive_or(registers.b, operand.value),
        ),
        output: option.None,
      )
    }

    BSTInstruction(operand) -> {
      let operand_value = evaluate_combo_operand(registers, operand)
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          b: operand_value % 8,
        ),
        output: option.None,
      )
    }

    JNZInstruction(operand) -> {
      case registers.a {
        0 ->
          InstructionResult(
            registers: Registers(..registers, pc: registers.pc + 2),
            output: option.None,
          )

        _ -> {
          InstructionResult(
            registers: Registers(..registers, pc: operand.value),
            output: option.None,
          )
        }
      }
    }

    BXCInstruction -> {
      InstructionResult(
        registers: Registers(
          ..registers,
          pc: registers.pc + 2,
          b: int.bitwise_exclusive_or(registers.b, registers.c),
        ),
        output: option.None,
      )
    }

    OutInstruction(operand) -> {
      InstructionResult(
        registers: Registers(..registers, pc: registers.pc + 2),
        output: option.Some(evaluate_combo_operand(registers, operand) % 8),
      )
    }
  }
}

fn evaluate_div_instruction(registers: Registers, operand: ComboOperand) -> Int {
  let combo_value = evaluate_combo_operand(registers, operand)

  registers.a / int_pow(2, combo_value)
}

fn evaluate_combo_operand(registers: Registers, operand: ComboOperand) -> Int {
  case operand {
    LiteralComboOperand(value:) -> value
    RegisterAComboOperand -> registers.a
    RegisterBComboOperand -> registers.b
    RegisterCComboOperand -> registers.c
  }
}

pub fn int_pow(base: Int, n: Int) -> Int {
  use <- bool.guard(n < 0, 0)
  use <- bool.guard(n == 0, 1)

  base * int_pow(base, n - 1)
}

fn parse_input(
  input: String,
) -> Result(#(Registers, #(List(Int), Program)), String) {
  let chunks =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  case chunks {
    [register_chunk, program_chunk] -> {
      use registers <- result.try(parse_registers(register_chunk))
      use #(raw_program, program) <- result.try(parse_program(program_chunk))

      Ok(#(registers, #(raw_program, program)))
    }
    _ -> Error("Input must contain an input chunk and a program chunk")
  }
}

fn parse_registers(register_input: String) -> Result(Registers, String) {
  let register_lines = string.split(register_input, "\n")
  case register_lines {
    [a_line, b_line, c_line] -> {
      use a <- result.try(parse_register(a_line, "A"))
      use b <- result.try(parse_register(b_line, "B"))
      use c <- result.try(parse_register(c_line, "C"))

      Ok(Registers(pc: 0, a:, b:, c:))
    }
    _ ->
      Error("Registers chunk must contain exactly three registers, A, B, and C")
  }
}

fn parse_register(line: String, name: String) -> Result(Int, String) {
  let prefix = "Register " <> name <> ": "
  use <- bool.guard(
    !string.starts_with(line, prefix),
    Error("Malformed line for register " <> name),
  )

  let raw_value = string.drop_start(line, string.length(prefix))

  raw_value
  |> int.parse()
  |> result.map_error(fn(_nil) { "Invalid register value " <> raw_value })
}

fn parse_program(program_input: String) -> Result(#(List(Int), Program), String) {
  let prefix = "Program: "
  use <- bool.guard(
    !string.starts_with(program_input, prefix),
    Error("Malformed program line"),
  )

  let input_values_result =
    program_input
    |> string.drop_start(string.length(prefix))
    |> string.split(",")
    |> list.try_map(fn(value) {
      value
      |> int.parse()
      |> result.map_error(fn(_nil) { "Invalid program value " <> value })
    })

  use input_values <- result.try(input_values_result)

  input_values
  |> list.sized_chunk(2)
  |> list.try_map(fn(chunk) {
    case chunk {
      [a, b] -> parse_instruction(a, b)
      _ -> Error("Program must contain an even number of items")
    }
  })
  |> result.map(fn(instructions) {
    let program =
      instructions
      |> list.index_map(fn(instruction, idx) { #(idx * 2, instruction) })
      |> dict.from_list()
      |> Program()

    #(input_values, program)
  })
}

fn parse_instruction(opcode: Int, operand: Int) -> Result(Instruction, String) {
  case opcode {
    0 -> result.map(parse_combo_operand(operand), ADVInstruction)
    1 -> Ok(BXLInstruction(LiteralOperand(operand)))
    2 -> result.map(parse_combo_operand(operand), BSTInstruction)
    3 -> Ok(JNZInstruction(LiteralOperand(operand)))
    4 -> Ok(BXCInstruction)
    5 -> result.map(parse_combo_operand(operand), OutInstruction)
    6 -> result.map(parse_combo_operand(operand), BDVInstruction)
    7 -> result.map(parse_combo_operand(operand), CDVInstruction)
    _ -> Error("Invalid opcode " <> int.to_string(opcode))
  }
}

fn parse_combo_operand(operand: Int) -> Result(ComboOperand, String) {
  case operand {
    0 | 1 | 2 | 3 -> Ok(LiteralComboOperand(operand))
    4 -> Ok(RegisterAComboOperand)
    5 -> Ok(RegisterBComboOperand)
    6 -> Ok(RegisterCComboOperand)
    7 -> Error("Combo operand 7 should never appear")
    _ -> Error("Invalid combo operand: " <> int.to_string(operand))
  }
}

fn try_pop(list list: List(a), or or: b, next next: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> or
    [head, ..rest] -> {
      next(head, rest)
    }
  }
}
