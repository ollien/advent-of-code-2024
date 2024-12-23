import advent_of_code_2024
import gleam/bool
import gleam/deque
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string

const max_row: Int = 70

const max_col: Int = 70

const init_elements: Int = 1024

type Position {
  Position(row: Int, col: Int)
}

type Step {
  Step(position: Position, depth: Int)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use positions <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(positions))
  io.println("Part 2: " <> part2(positions))
  Ok(Nil)
}

fn part1(positions: List(Position)) -> String {
  let obstacles =
    positions
    |> list.take(init_elements)
    |> set.from_list()

  let steps_result =
    bfs(
      deque.from_list([Step(position: Position(row: 0, col: 0), depth: 0)]),
      Position(row: max_row, col: max_col),
      obstacles,
      set.new(),
    )

  case steps_result {
    Ok(n) -> int.to_string(n)
    Error(Nil) -> "No solution found"
  }
}

fn part2(positions: List(Position)) -> String {
  let #(front, back) = #(
    list.take(positions, init_elements),
    list.drop(positions, init_elements),
  )

  case do_part_2(set.from_list(front), back) {
    Ok(position) ->
      int.to_string(position.col) <> "," <> int.to_string(position.row)
    Error(Nil) -> "No solution found"
  }
}

fn do_part_2(
  obstacles: set.Set(Position),
  positions: List(Position),
) -> Result(Position, Nil) {
  use new_position, positions <- try_pop(positions, Error(Nil))

  let obstacles = set.insert(obstacles, new_position)
  let steps_result =
    bfs(
      deque.from_list([Step(position: Position(row: 0, col: 0), depth: 0)]),
      Position(row: max_row, col: max_col),
      obstacles,
      set.new(),
    )

  case steps_result {
    Ok(_n) -> do_part_2(obstacles, positions)
    Error(Nil) -> Ok(new_position)
  }
}

fn bfs(
  to_visit: deque.Deque(Step),
  target: Position,
  obstacles: set.Set(Position),
  visited: set.Set(Position),
) -> Result(Int, Nil) {
  use step, to_visit <- try_pop_front(to_visit, Error(Nil))
  use <- bool.guard(step.position == target, Ok(step.depth))
  use <- bool.lazy_guard(set.contains(visited, step.position), fn() {
    bfs(to_visit, target, obstacles, visited)
  })

  let visited = set.insert(visited, step.position)
  let to_visit =
    step.position
    |> neighbors()
    |> list.filter(fn(neighbor) {
      !set.contains(obstacles, neighbor)
      && neighbor.row >= 0
      && neighbor.row <= max_row
      && neighbor.col >= 0
      && neighbor.col <= max_col
    })
    |> list.fold(from: to_visit, with: fn(to_visit, neighbor) {
      deque.push_back(to_visit, Step(position: neighbor, depth: step.depth + 1))
    })

  bfs(to_visit, target, obstacles, visited)
}

fn neighbors(position: Position) -> List(Position) {
  [
    Position(..position, row: position.row + 1),
    Position(..position, row: position.row - 1),
    Position(..position, col: position.col + 1),
    Position(..position, col: position.col - 1),
  ]
}

fn parse_input(input: String) -> Result(List(Position), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line)
}

fn parse_line(input_line: String) -> Result(Position, String) {
  case string.split(input_line, ",") {
    [left, right] -> {
      use col <- result.try(parse_int(left))
      use row <- result.try(parse_int(right))

      Ok(Position(row:, col:))
    }
    _ -> {
      Error("Malformed input line, must have two components")
    }
  }
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Malformed int " <> s })
}

fn try_pop_front(
  queue queue: deque.Deque(a),
  or or: b,
  next next: fn(a, deque.Deque(a)) -> b,
) -> b {
  case deque.pop_front(queue) {
    Error(Nil) -> or
    Ok(#(front, rest)) -> {
      next(front, rest)
    }
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
