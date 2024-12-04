import advent_of_code_2024
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

type Position {
  Position(row: Int, column: Int)
}

type Vector {
  Vector(row: Int, column: Int)
}

type DirectedPosition {
  DirectedPosition(position: Position, direction: Vector)
}

type WordSearch {
  WordSearch(letters: dict.Dict(Position, String))
}

fn run(input: String) -> Result(Nil, String) {
  let word_search = build_word_search(input)
  io.println("Part 1: " <> part1(word_search))
  io.println("Part 2: " <> part2(word_search))

  Ok(Nil)
}

fn part1(word_search: WordSearch) -> String {
  word_search
  |> starting_positions("X")
  |> list.flat_map(fn(position) {
    list.map(all_vectors(), fn(direction) {
      DirectedPosition(position: position, direction:)
    })
  })
  |> list.filter(fn(directed) { is_word_at(word_search, "XMAS", directed) })
  |> list.length()
  |> int.to_string()
}

fn part2(word_search: WordSearch) -> String {
  word_search
  |> starting_positions("A")
  |> list.filter(fn(position) { is_x_shaped_mas(word_search, position) })
  |> list.length()
  |> int.to_string()
}

fn is_word_at(
  word_search: WordSearch,
  word: String,
  start_at: DirectedPosition,
) -> Bool {
  do_is_word_at(
    in: word_search,
    at: start_at.position,
    in_direction: start_at.direction,
    remaining: string.to_graphemes(word),
    depth: 0,
  )
}

fn do_is_word_at(
  in word_search: WordSearch,
  at position: Position,
  in_direction direction: Vector,
  remaining to_find: List(String),
  depth depth: Int,
) -> Bool {
  use next, rest <- try_pop(to_find, or: True)

  case dict.get(word_search.letters, position) {
    Ok(letter) if letter == next -> {
      let next_position = add_vector_to(position, direction)
      do_is_word_at(
        in: word_search,
        at: next_position,
        in_direction: direction,
        remaining: rest,
        depth: depth + 1,
      )
    }

    Error(Nil) | Ok(_letter) -> {
      False
    }
  }
}

fn is_x_shaped_mas(word_search: WordSearch, position: Position) -> Bool {
  let m_directed_positions =
    diagonal_vectors()
    |> list.filter_map(fn(direction) {
      let position = add_vector_to(position, direction)

      case dict.get(word_search.letters, position) {
        Ok("M") ->
          Ok(DirectedPosition(
            position:,
            // Flip the direction; we start at the "A", but the search will go from the "M" (which is the other way)
            direction: negate_vector(direction),
          ))
        Ok(_) | Error(Nil) -> Error(Nil)
      }
    })

  case m_directed_positions {
    [m1, m2] -> {
      is_word_at(word_search, "MAS", m1) && is_word_at(word_search, "MAS", m2)
    }

    _ -> False
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

fn add_vector_to(position: Position, vector: Vector) -> Position {
  Position(
    row: position.row + vector.row,
    column: position.column + vector.column,
  )
}

fn negate_vector(vector: Vector) -> Vector {
  Vector(row: vector.row * -1, column: vector.column * -1)
}

fn diagonal_vectors() -> List(Vector) {
  list.flat_map(list.range(from: -1, to: 1), fn(row_delta) {
    list.filter_map(list.range(from: -1, to: 1), fn(col_delta) {
      case int.absolute_value(row_delta), int.absolute_value(col_delta) {
        1, 1 -> Ok(Vector(row: row_delta, column: col_delta))
        _, _ -> Error(Nil)
      }
    })
  })
}

fn all_vectors() -> List(Vector) {
  list.flat_map(list.range(from: -1, to: 1), fn(row_delta) {
    list.filter_map(list.range(from: -1, to: 1), fn(col_delta) {
      case row_delta, col_delta {
        0, 0 -> Error(Nil)
        row_delta, col_delta -> Ok(Vector(row: row_delta, column: col_delta))
      }
    })
  })
}

fn starting_positions(
  word_search: WordSearch,
  starting_letter: String,
) -> List(Position) {
  word_search.letters
  |> dict.to_list()
  |> list.filter_map(fn(entry) {
    case entry {
      #(position, letter) if letter == starting_letter -> Ok(position)
      _ -> Error(Nil)
    }
  })
}

fn build_word_search(input: String) -> WordSearch {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.index_fold(from: dict.new(), with: fn(all_letters, line, row_idx) {
    line
    |> string.to_graphemes()
    |> list.index_fold(from: all_letters, with: fn(letters, char, col_idx) {
      dict.insert(letters, Position(row: row_idx, column: col_idx), char)
    })
  })
  |> WordSearch()
}
