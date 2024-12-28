import advent_of_code_2024
import gleam/bool
import gleam/deque
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree

type Direction {
  Up
  Down
  Left
  Right
}

type Action {
  GoLeft
  GoRight
  GoUp
  GoDown
  Activate
}

type Keypad {
  Keypad(keys: dict.Dict(String, dict.Dict(Direction, String)))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  let codes =
    input
    |> string.trim_end()
    |> string.split("\n")

  io.println("Part 1: " <> part1(codes))
  Ok(Nil)
}

fn part1(codes: List(String)) -> String {
  case do_part1(codes) {
    Ok(solution) -> solution
    Error(err) -> "Failed to solve: " <> err
  }
}

fn do_part1(codes: List(String)) -> Result(String, String) {
  use solutions <- result.try(list.try_map(codes, solve_code))

  solutions
  |> int.sum()
  |> int.to_string()
  |> Ok()
}

fn solve_code(code: String) -> Result(Int, String) {
  use numpad_paths <- result.try(make_paths_to_enter(make_numpad(), code))
  use numeric_part <- result.try(
    code
    |> string.drop_end(1)
    |> int.parse()
    |> result.map_error(fn(_nil) { "Invalid numeric part of code" }),
  )

  list.try_map(numpad_paths, fn(path) {
    path
    |> path_to_string()
    |> string.to_graphemes()
    |> list.prepend("A")
    |> list.window_by_2()
    |> list.try_map(fn(pair) {
      let #(from, to) = pair
      make_shortest_path_to_press_key(make_directional_pad(), from, to, 3)
    })
    |> result.map(int.sum)
  })
  |> result.then(fn(lengths) {
    lengths
    |> list.map(fn(length) { length * numeric_part })
    |> list.reduce(int.min)
    |> result.map_error(fn(__nil) { "No solutions found" })
  })
}

fn print_path(path: List(Action)) -> Nil {
  case path {
    [] -> io.print("\n")
    [head, ..rest] -> {
      io.print(action_to_string(head))
      print_path(rest)
    }
  }
}

fn path_to_string(path: List(Action)) -> String {
  do_path_to_string(path, string_tree.new())
}

fn do_path_to_string(path: List(Action), acc: string_tree.StringTree) -> String {
  case path {
    [] -> {
      string_tree.to_string(acc)
    }

    [head, ..rest] -> {
      let action_str = action_to_string(head)
      let acc = string_tree.append(acc, action_str)

      do_path_to_string(rest, acc)
    }
  }
}

fn action_to_string(action: Action) -> String {
  case action {
    GoLeft -> "<"
    GoRight -> ">"
    GoDown -> "v"
    GoUp -> "^"
    Activate -> "A"
  }
}

fn make_paths_to_enter(
  keypad: Keypad,
  sequence: String,
) -> Result(List(List(Action)), String) {
  sequence
  |> string.to_graphemes()
  |> list.prepend("A")
  |> list.window_by_2()
  |> list.fold_until(from: Ok([]), with: fn(acc, pair) {
    let assert Ok(acc) = acc
    let #(start, end) = pair
    case make_paths_to_press_key(keypad, start, end) {
      Ok(paths) if acc == [] -> {
        list.Continue(Ok(paths))
      }

      Ok(paths) -> {
        let acc =
          list.flat_map(acc, fn(acc_path) {
            list.map(paths, fn(path) { list.flatten([acc_path, path]) })
          })

        list.Continue(Ok(acc))
      }
      Error(err) -> list.Stop(Error(err))
    }
  })
}

fn make_paths_to_enter_times(
  keypad: Keypad,
  sequence: String,
  times: Int,
) -> Result(List(List(Action)), String) {
  use <- bool.guard(
    when: times <= 0,
    return: Error("Must have at least one iteration of keypress"),
  )

  use paths <- result.try(make_paths_to_enter(keypad, sequence))
  io.debug(list.length(paths))

  paths
  |> list.try_map(fn(path) {
    case times {
      1 -> Ok([path])
      _ -> make_paths_to_enter_times(keypad, path_to_string(path), times - 1)
    }
  })
  |> result.map(list.flatten)
}

fn make_shortest_path_to_press_key(
  keypad keypad: Keypad,
  from start: String,
  to target: String,
  times n: Int,
) -> Result(Int, String) {
  use <- bool.guard(
    when: n <= 0,
    return: Error("Must have at least one iteration of keypress"),
  )

  use <- bool.guard(when: n == 1, return: Ok(1))

  use paths <- result.try(make_paths_to_press_key(keypad, start, target))

  paths
  |> list.try_map(fn(path) {
    path
    |> path_to_string()
    |> string.to_graphemes()
    |> list.prepend("A")
    |> list.window_by_2()
    |> list.try_map(fn(pair) {
      let #(from, to) = pair
      make_shortest_path_to_press_key(make_directional_pad(), from, to, n - 1)
    })
    |> result.map(int.sum)
  })
  |> result.then(fn(x) {
    list.reduce(x, int.min)
    |> result.map_error(fn(_nil) { "No paths" })
  })
}

fn make_paths_to_press_key(
  keypad: Keypad,
  start: String,
  target: String,
) -> Result(List(List(Action)), String) {
  use distances <- result.try(make_distances_in_path_to_target(
    keypad,
    start,
    target,
  ))

  trace_paths_with_distances(keypad, start, target, distances)
}

fn trace_paths_with_distances(
  keypad: Keypad,
  start: String,
  end: String,
  distances: dict.Dict(String, Int),
) -> Result(List(List(Action)), String) {
  use <- bool.guard(start == end, return: Ok([[Activate]]))

  use neighbors <- result.try(
    dict.get(keypad.keys, start)
    |> result.map_error(fn(_nil) { "Invalid key " <> start }),
  )

  use current_distance <- result.try(
    dict.get(distances, start)
    |> result.map_error(fn(_nil) { "Unknown distance for " <> start }),
  )

  neighbors
  |> dict.filter(fn(_action, neighbor) {
    dict.get(distances, neighbor)
    |> result.map(fn(distance) { distance == current_distance + 1 })
    |> result.unwrap(or: False)
  })
  |> dict.to_list()
  |> list.try_map(fn(entry) {
    let #(direction, neighbor) = entry

    use subpaths <- result.try(trace_paths_with_distances(
      keypad,
      neighbor,
      end,
      distances,
    ))

    Ok(
      list.map(subpaths, fn(subpath) {
        [direction_to_action(direction), ..subpath]
      }),
    )
  })
  |> result.map(list.flatten)
}

fn make_distances_in_path_to_target(
  keypad: Keypad,
  start: String,
  target: String,
) -> Result(dict.Dict(String, Int), String) {
  do_make_distances_in_path_to_target(
    keypad,
    target,
    deque.from_list([start]),
    dict.from_list([#(start, 0)]),
  )
}

fn do_make_distances_in_path_to_target(
  keypad: Keypad,
  target: String,
  to_visit: deque.Deque(String),
  distances: dict.Dict(String, Int),
) -> Result(dict.Dict(String, Int), String) {
  use visiting, to_visit <- try_pop_front(
    to_visit,
    or: Error("No path possible to visit " <> target),
  )

  use <- bool.guard(visiting == target, Ok(distances))

  use neighbors <- result.try(
    dict.get(keypad.keys, visiting)
    |> result.map_error(fn(_nil) { "Invalid key " <> visiting }),
  )
  use visiting_distance <- result.try(
    dict.get(distances, visiting)
    |> result.map_error(fn(_nil) { "key has no distance stored: " <> visiting }),
  )
  let #(to_visit, distances) =
    dict.fold(
      neighbors,
      from: #(to_visit, distances),
      with: fn(acc, _direction, neighbor) {
        let #(to_visit, distances) = acc
        use <- bool.guard(dict.has_key(distances, neighbor), #(
          to_visit,
          distances,
        ))

        let distances = dict.insert(distances, neighbor, visiting_distance + 1)
        let to_visit = deque.push_back(to_visit, neighbor)

        #(to_visit, distances)
      },
    )

  do_make_distances_in_path_to_target(keypad, target, to_visit, distances)
}

fn direction_to_action(direction: Direction) -> Action {
  case direction {
    Left -> GoLeft
    Right -> GoRight
    Up -> GoUp
    Down -> GoDown
  }
}

fn make_numpad() -> Keypad {
  Keypad(
    keys: dict.new()
    |> dict.insert(
      "0",
      dict.new() |> dict.insert(Right, "A") |> dict.insert(Up, "2"),
    )
    |> dict.insert(
      "A",
      dict.new() |> dict.insert(Left, "0") |> dict.insert(Up, "3"),
    )
    |> dict.insert(
      "3",
      dict.new()
        |> dict.insert(Left, "2")
        |> dict.insert(Up, "6")
        |> dict.insert(Down, "A"),
    )
    |> dict.insert(
      "2",
      dict.new()
        |> dict.insert(Left, "1")
        |> dict.insert(Right, "3")
        |> dict.insert(Up, "5")
        |> dict.insert(Down, "0"),
    )
    |> dict.insert(
      "1",
      dict.new()
        |> dict.insert(Right, "2")
        |> dict.insert(Up, "4"),
    )
    |> dict.insert(
      "6",
      dict.new()
        |> dict.insert(Left, "5")
        |> dict.insert(Down, "3")
        |> dict.insert(Up, "9"),
    )
    |> dict.insert(
      "5",
      dict.new()
        |> dict.insert(Left, "4")
        |> dict.insert(Right, "6")
        |> dict.insert(Up, "8")
        |> dict.insert(Down, "2"),
    )
    |> dict.insert(
      "4",
      dict.new()
        |> dict.insert(Right, "5")
        |> dict.insert(Up, "7")
        |> dict.insert(Down, "1"),
    )
    |> dict.insert(
      "9",
      dict.new()
        |> dict.insert(Left, "8")
        |> dict.insert(Down, "6"),
    )
    |> dict.insert(
      "8",
      dict.new()
        |> dict.insert(Left, "7")
        |> dict.insert(Right, "9")
        |> dict.insert(Down, "5"),
    )
    |> dict.insert(
      "7",
      dict.new()
        |> dict.insert(Right, "8")
        |> dict.insert(Down, "4"),
    ),
  )
}

fn make_directional_pad() -> Keypad {
  Keypad(
    keys: dict.new()
    |> dict.insert("<", dict.new() |> dict.insert(Right, "v"))
    |> dict.insert(
      "v",
      dict.new()
        |> dict.insert(Left, "<")
        |> dict.insert(Right, ">")
        |> dict.insert(Up, "^"),
    )
    |> dict.insert(
      ">",
      dict.new() |> dict.insert(Left, "v") |> dict.insert(Up, "A"),
    )
    |> dict.insert(
      "^",
      dict.new() |> dict.insert(Down, "v") |> dict.insert(Right, "A"),
    )
    |> dict.insert(
      "A",
      dict.new() |> dict.insert(Down, ">") |> dict.insert(Left, "^"),
    ),
  )
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
