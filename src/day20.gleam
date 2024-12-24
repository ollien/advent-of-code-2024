import advent_of_code_2024
import gleam/bool
import gleam/deque
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type Dimensions {
  Dimensions(width: Int, height: Int)
}

type Map {
  Map(
    start: Position,
    end: Position,
    walls: set.Set(Position),
    dimensions: Dimensions,
  )
}

type RaceState {
  RaceState(position: Position, cheated: Bool)
}

type RaceStep {
  RaceStep(state: RaceState, distance: Int, visited: set.Set(Position))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(map))
  Ok(Nil)
}

fn part1(map: Map) -> String {
  let steps =
    bfs(
      map,
      deque.from_list([
        RaceStep(
          distance: 0,
          visited: set.new(),
          state: RaceState(position: map.start, cheated: False),
        ),
      ]),
      [],
    )

  case list.reduce(steps, int.max) {
    Error(Nil) -> "No solutions found"
    Ok(max_steps) -> {
      steps
      |> list.map(fn(n) { max_steps - n })
      |> list.count(fn(n) { n >= 100 })
      |> int.to_string()
    }
  }
}

fn bfs(
  map: Map,
  to_visit: deque.Deque(RaceStep),
  solution_distances: List(Int),
) -> List(Int) {
  use visiting, to_visit <- try_pop_front(to_visit, or: solution_distances)
  // print_map(map, visiting.state.position, visiting.state.cheated)
  use <- bool.lazy_guard(when: visiting.state.position == map.end, return: fn() {
    bfs(map, to_visit, [visiting.distance, ..solution_distances])
  })

  let visiting =
    RaceStep(
      ..visiting,
      visited: set.insert(visiting.visited, visiting.state.position),
    )

  let to_visit =
    next_steps(map, visiting)
    |> list.filter(fn(step) {
      !set.contains(visiting.visited, step.state.position)
    })
    |> list.fold(from: to_visit, with: deque.push_back)

  bfs(map, to_visit, solution_distances)
}

fn next_steps(map: Map, race_step: RaceStep) -> List(RaceStep) {
  neighbors(race_step.state.position)
  |> list.filter(fn(neighbor) {
    neighbor.col >= 0
    && neighbor.col < map.dimensions.width
    && neighbor.row >= 0
    && neighbor.row < map.dimensions.height
  })
  |> list.filter_map(fn(neighbor) {
    case race_step.state.cheated, set.contains(map.walls, neighbor) {
      True, True -> Error(Nil)
      True, False ->
        Ok(
          RaceStep(
            ..race_step,
            distance: race_step.distance + 1,
            state: RaceState(position: neighbor, cheated: True),
          ),
        )

      False, False ->
        Ok(
          RaceStep(
            ..race_step,
            distance: race_step.distance + 1,
            state: RaceState(position: neighbor, cheated: False),
          ),
        )

      False, True ->
        Ok(
          RaceStep(
            ..race_step,
            distance: race_step.distance + 1,
            state: RaceState(position: neighbor, cheated: True),
          ),
        )
    }
  })
}

fn print_map(map: Map, highlight: Position, cheated: Bool) -> Nil {
  list.each(list.range(0, map.dimensions.height - 1), fn(row) {
    list.each(list.range(0, map.dimensions.width - 1), fn(col) {
      let position = Position(row:, col:)
      use <- bool.lazy_guard(position == highlight && cheated, fn() {
        io.print_error("C")
      })
      use <- bool.lazy_guard(position == highlight, fn() { io.print_error("O") })
      use <- bool.lazy_guard(set.contains(map.walls, position), fn() {
        io.print_error("#")
      })
      io.print_error(".")
    })
    io.print_error("\n")
  })
}

fn parse_input(input: String) -> Result(Map, String) {
  let lines =
    input
    |> string.trim_end()
    |> string.split("\n")

  use dimensions <- result.try(measure_input(lines))

  let tiles =
    lines
    |> list.index_fold(from: [], with: fn(acc, line, row) {
      list.index_fold(
        string.to_graphemes(line),
        from: acc,
        with: fn(acc, char, col) { [#(char, Position(row:, col:)), ..acc] },
      )
    })
    |> list.group(fn(pair) { pair.0 })

  use #(_, start) <- result.try(
    get_exactly_one(tiles, "S")
    |> result.map_error(fn(_nil) { "There must be exactly one start tile" }),
  )

  use #(_, end) <- result.try(
    get_exactly_one(tiles, "E")
    |> result.map_error(fn(_nil) { "There must be exactly one end tile" }),
  )

  let walls =
    tiles
    |> dict.get("#")
    |> result.unwrap(or: [])
    |> list.map(fn(pair) { pair.1 })
    |> set.from_list()

  Ok(Map(walls:, start:, end:, dimensions:))
}

fn measure_input(input_lines: List(String)) -> Result(Dimensions, String) {
  case input_lines {
    [] -> {
      Ok(Dimensions(height: 0, width: 0))
    }
    [first_line, ..rest_lines] -> {
      let height = list.length(input_lines)
      let width = string.length(first_line)
      case list.all(rest_lines, fn(line) { string.length(line) == width }) {
        True -> Ok(Dimensions(height:, width:))
        False -> Error("Input must be rectangular")
      }
    }
  }
}

fn get_exactly_one(d: dict.Dict(a, List(b)), key: a) -> Result(b, Nil) {
  case dict.get(d, key) {
    Ok([one]) -> Ok(one)
    Error(Nil) | Ok(_) -> Error(Nil)
  }
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

fn neighbors(position: Position) -> List(Position) {
  [
    Position(..position, row: position.row + 1),
    Position(..position, row: position.row - 1),
    Position(..position, col: position.col + 1),
    Position(..position, col: position.col - 1),
  ]
}
