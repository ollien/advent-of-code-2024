import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
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

type WordSearch {
  WordSearch(height: Int, width: Int, letters: dict.Dict(Position, String))
}

fn run(input: String) -> Result(Nil, String) {
  let word_search = build_word_search(input)
  io.println("Part 1: " <> part1(word_search))

  Ok(Nil)
}

fn part1(word_search: WordSearch) -> String {
  word_search
  |> starting_positions()
  |> list.flat_map(fn(position) {
    vectors()
    |> list.map(fn(vector) { #(position, vector) })
  })
  |> list.map(fn(pair) {
    let #(position, vector) = pair
    count_xmas_from(word_search, position, vector)
  })
  |> int.sum()
  |> int.to_string()
}

fn count_xmas_from(
  word_search: WordSearch,
  start_at: Position,
  direction: Vector,
) -> Int {
  do_count_xmas_from(
    in: word_search,
    at: start_at,
    in_direction: direction,
    remaining: ["X", "M", "A", "S"],
    depth: 0,
  )
}

fn do_count_xmas_from(
  in word_search: WordSearch,
  at position: Position,
  in_direction direction: Vector,
  remaining to_find: List(String),
  depth depth: Int,
) -> Int {
  use next, rest <- try_pop(to_find, or: 1)

  case dict.get(word_search.letters, position) {
    Ok(letter) if letter == next -> {
      let next_position = add_vector_to(position, direction)
      do_count_xmas_from(
        in: word_search,
        at: next_position,
        in_direction: direction,
        remaining: rest,
        depth: depth + 1,
      )
    }

    Error(Nil) | Ok(_letter) -> {
      0
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

fn add_vector_to(position: Position, vector: Vector) -> Position {
  Position(
    row: position.row + vector.row,
    column: position.column + vector.column,
  )
}

fn vectors() -> List(Vector) {
  list.flat_map(list.range(from: -1, to: 1), fn(row_delta) {
    list.filter_map(list.range(from: -1, to: 1), fn(col_delta) {
      case row_delta, col_delta {
        0, 0 -> Error(Nil)
        row_delta, col_delta -> Ok(Vector(row: row_delta, column: col_delta))
      }
    })
  })
}

fn starting_positions(word_search: WordSearch) -> List(Position) {
  word_search.letters
  |> dict.to_list()
  |> list.filter_map(fn(entry) {
    let #(position, letter) = entry
    case letter {
      "X" -> Ok(position)
      _ -> Error(Nil)
    }
  })
}

fn build_word_search(input: String) -> WordSearch {
  let letters = build_word_search_letters(input)

  WordSearch(
    letters:,
    height: find_dimension(letters, fn(pos) { pos.row }),
    width: find_dimension(letters, fn(pos) { pos.column }),
  )
}

fn build_word_search_letters(input: String) -> dict.Dict(Position, String) {
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
}

fn find_dimension(
  letters: dict.Dict(Position, a),
  extract_dim: fn(Position) -> Int,
) -> Int {
  letters
  |> dict.keys()
  |> list.map(extract_dim)
  |> list.reduce(int.max)
  |> result.map(fn(max_index) { max_index + 1 })
  |> result.unwrap(or: 0)
}
