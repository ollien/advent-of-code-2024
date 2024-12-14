import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/set
import gleam/string

const grid_height: Int = 103

const grid_width: Int = 101

// for the samples
// const grid_height: Int = 7

// const grid_width: Int = 11

type Position {
  Position(row: Int, col: Int)
}

type Velocity {
  Velocity(row: Int, col: Int)
}

type Robot {
  Robot(position: Position, velocity: Velocity)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use robots <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(robots))
  io.println("Part 2: use your eyes to validate the answer")
  part2(robots)

  Ok(Nil)
}

fn part1(robots: List(Robot)) -> String {
  robots
  |> list.map(fn(robot) {
    let next_pos =
      Position(
        col: add_and_wrap(
          robot.position.col,
          robot.velocity.col * 100,
          grid_width,
        ),
        row: add_and_wrap(
          robot.position.row,
          robot.velocity.row * 100,
          grid_height,
        ),
      )

    Robot(..robot, position: next_pos)
  })
  |> safety_factor()
  |> int.to_string()
}

fn part2(robots: List(Robot)) {
  do_part2(robots, 0, False)
}

fn do_part2(robots: List(Robot), steps: Int, print_every: Bool) {
  let upd_robots =
    robots
    |> list.map(fn(robot) {
      let next_pos =
        Position(
          col: add_and_wrap(
            robot.position.col,
            robot.velocity.col * steps,
            grid_width,
          ),
          row: add_and_wrap(
            robot.position.row,
            robot.velocity.row * steps,
            grid_height,
          ),
        )

      Robot(..robot, position: next_pos)
    })

  case print_every {
    True -> print_grid(upd_robots)
    False -> Nil
  }

  let candidate =
    upd_robots
    |> list.group(fn(robot) { robot.position.row })
    |> dict.map_values(fn(_key, robots) {
      list.map(robots, fn(robot) { robot.position.col })
    })
    |> dict.values()
    |> list.any(fn(row) { has_n_consecutive(row, 30) })

  case candidate {
    True -> {
      io.println(int.to_string(steps))
      print_grid(upd_robots)
    }
    False -> do_part2(robots, steps + 1, False)
  }
}

fn has_n_consecutive(numbers: List(Int), n: Int) -> Bool {
  numbers
  |> list.sort(by: int.compare)
  |> do_has_n_consecutive(n, n)
}

fn do_has_n_consecutive(numbers: List(Int), count: Int, remaining: Int) -> Bool {
  use <- bool.guard(remaining == 0, True)
  case numbers {
    [] -> False
    [_n] -> remaining == 1
    [n, m] -> {
      n + 1 == m && remaining == 2
    }
    [n, m, ..rest] if n + 1 == m -> {
      do_has_n_consecutive([m, ..rest], count, remaining - 1)
    }
    [_n, m, ..rest] -> {
      do_has_n_consecutive([m, ..rest], count, remaining)
    }
  }
}

fn print_grid(robots: List(Robot)) {
  let robot_positions =
    robots
    |> list.map(fn(robot) { robot.position })
    |> set.from_list()

  list.each(list.range(from: 0, to: grid_height - 1), fn(row) {
    list.each(list.range(from: 0, to: grid_width - 1), fn(col) {
      case set.contains(robot_positions, Position(row:, col:)) {
        True -> io.print("#")
        False -> io.print(".")
      }
    })
    io.print("\n")
  })
}

fn add_and_wrap(a: Int, b: Int, limit limit: Int) -> Int {
  // https://stackoverflow.com/a/39740009
  case b >= 0 {
    True -> { a + b } % limit
    False -> { { a + b } - b * limit } % limit
  }
}

fn safety_factor(robots: List(Robot)) -> Int {
  let height_midpoint = grid_height / 2
  let width_midpoint = grid_width / 2
  let quad1 =
    list.count(robots, fn(robot) {
      robot.position.row < height_midpoint
      && robot.position.col > width_midpoint
    })

  let quad2 =
    list.count(robots, fn(robot) {
      robot.position.row < height_midpoint
      && robot.position.col < width_midpoint
    })

  let quad3 =
    list.count(robots, fn(robot) {
      robot.position.row > height_midpoint
      && robot.position.col < width_midpoint
    })

  let quad4 =
    list.count(robots, fn(robot) {
      robot.position.row > height_midpoint
      && robot.position.col > width_midpoint
    })

  quad1 * quad2 * quad3 * quad4
}

fn parse_input(input: String) -> Result(List(Robot), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_input_line)
}

fn parse_input_line(line: String) -> Result(Robot, String) {
  let assert Ok(pattern) =
    regexp.compile(
      "^p=(-?\\d+),(-?\\d+) v=(-?\\d+),(-?\\d+)",
      regexp.Options(case_insensitive: False, multi_line: False),
    )

  case regexp.scan(pattern, line) {
    [] -> Error("Line did not match pattern - " <> line)
    [
      regexp.Match(
        submatches: [
          option.Some(px),
          option.Some(py),
          option.Some(vx),
          option.Some(vy),
        ],
        ..,
      ),
    ] -> {
      let assert Ok(px) = int.parse(px)
      let assert Ok(py) = int.parse(py)
      let assert Ok(vx) = int.parse(vx)
      let assert Ok(vy) = int.parse(vy)

      Ok(Robot(
        position: Position(row: py, col: px),
        velocity: Velocity(row: vy, col: vx),
      ))
    }
    _ -> panic as "it is not possible to have more than one match"
  }
}
