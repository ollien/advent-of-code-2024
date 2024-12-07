import advent_of_code_2024
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

type Operator {
  Add
  Multiply
}

type Calibration {
  Calibration(test_value: Int, operands: List(Int))
}

type Equation {
  Equation(result: Int, expression: Expression)
}

type Expression {
  ExpressionContinue(operand: Int, operator: Operator, rest: Expression)
  ExpressionEnd(operand: Int)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use calibrations <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(calibrations))

  Ok(Nil)
}

fn part1(calibrations: List(Calibration)) -> String {
  calibrations
  |> list.map(possible_equations)
  |> list.filter_map(fn(equations) {
    equations
    |> list.find(fn(equation) {
      // io.debug(#(
      //   equation.result,
      //   evaluate_expression(equation.expression),
      //   equation.expression,
      // ))
      equation.result == evaluate_expression(equation.expression)
    })
    |> result.map(fn(equation) { equation.result })
  })
  |> int.sum()
  |> int.to_string()
}

fn evaluate_expression(expression: Expression) -> Int {
  case expression {
    ExpressionEnd(operand:) -> operand

    ExpressionContinue(
      operand: operand1,
      operator:,
      rest: ExpressionEnd(operand: operand2),
    ) -> {
      apply_operation(operand1, operand2, operator)
    }

    ExpressionContinue(
      operand: operand1,
      operator:,
      rest: ExpressionContinue(
        operand: operand2,
        ..,
      ) as rest,
    ) -> {
      evaluate_expression(
        ExpressionContinue(
          ..rest,
          operand: apply_operation(operand1, operand2, operator),
        ),
      )
    }
  }
}

fn apply_operation(operand1: Int, operand2: Int, operator: Operator) -> Int {
  case operator {
    Add -> operand1 + operand2
    Multiply -> operand1 * operand2
  }
}

fn possible_equations(calibration: Calibration) -> List(Equation) {
  calibration.operands
  |> possible_expressions()
  |> list.map(fn(expression) {
    Equation(result: calibration.test_value, expression:)
  })
}

fn possible_expressions(operands: List(Int)) -> List(Expression) {
  case operands {
    [] -> []
    [operand] -> {
      [ExpressionEnd(operand:)]
    }
    [operand, ..rest_operands] -> {
      let rest_expressions = possible_expressions(rest_operands)
      list.flat_map(rest_expressions, fn(expr_rest) {
        list.map([Add, Multiply], fn(operator) {
          ExpressionContinue(operand:, operator:, rest: expr_rest)
        })
      })
    }
  }
}

fn parse_input(input: String) -> Result(List(Calibration), String) {
  input
  |> string.trim_end
  |> string.split("\n")
  |> list.index_map(fn(line, idx) { #(idx + 1, line) })
  |> list.try_map(fn(entry) {
    let #(line_no, line) = entry
    line
    |> parse_input_line()
    |> result.map_error(fn(err) {
      "Invalid input on line " <> int.to_string(line_no) <> ": " <> err
    })
  })
}

fn parse_input_line(line: String) -> Result(Calibration, String) {
  let assert Ok(pattern) =
    regexp.compile(
      "^([0-9]+):((?:\\s[0-9]+)+)$",
      with: regexp.Options(case_insensitive: False, multi_line: False),
    )

  case regexp.scan(pattern, line) {
    [] -> Error("Does not match pattern")
    [match] -> {
      // These are all guaranteed by the pattern
      let assert [option.Some(raw_test_value), option.Some(raw_operands)] =
        match.submatches
      let assert Ok(test_value) = int.parse(raw_test_value)
      let operands =
        raw_operands
        |> string.trim_start()
        |> string.split(" ")
        |> list.map(fn(raw_operand) {
          let assert Ok(operand) = int.parse(raw_operand)
          operand
        })

      Ok(Calibration(test_value:, operands:))
    }
    _ -> panic as "not possible to have more than one match"
  }
}
