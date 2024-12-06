import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

type Page =
  Int

type Input {
  Input(rules: List(PageRule), updates: List(Update))
}

type PageRule {
  PageRule(first: Page, second: Page)
}

type Update {
  Update(pages: List(Page))
}

type Adjacencies =
  dict.Dict(Page, set.Set(Page))

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))
  let adjacencies = build_adjacencies(input.rules)
  let #(valid_updates, invalid_updates) =
    list.partition(input.updates, fn(update) {
      is_update_valid(adjacencies, update)
    })

  io.println("Part 1: " <> part1(valid_updates))
  part2(adjacencies, invalid_updates)
  |> result.then(fn(answer) {
    io.println("Part 2: " <> answer)
    Ok(Nil)
  })
}

fn part1(valid_updates: List(Update)) -> String {
  valid_updates
  |> list.map(fn(update) {
    // These lists are guaranteed to be non-empty by our input parser
    let assert Ok(middle) = middle_element(update.pages)
    middle
  })
  |> int.sum()
  |> int.to_string()
}

fn part2(
  adjacencies: Adjacencies,
  invalid_updates: List(Update),
) -> Result(String, String) {
  invalid_updates
  |> list.try_map(fn(update) { make_valid_update(adjacencies, update) })
  |> result.map(part1)
  |> result.map_error(fn(_nil) { "No valid answers" })
}

fn is_update_valid(adjacencies: Adjacencies, update: Update) -> Bool {
  do_is_update_valid(adjacencies, update.pages)
}

fn do_is_update_valid(adjacencies: Adjacencies, remaining: List(Page)) -> Bool {
  use first, remaining <- try_pop(remaining, or: True)
  let all_after = set.from_list(remaining)
  let must_after =
    adjacencies
    |> dict.get(first)
    |> result.unwrap(or: set.new())

  let extraneous_after = set.difference(all_after, must_after)
  case set.is_empty(extraneous_after) {
    True -> do_is_update_valid(adjacencies, remaining)
    False -> False
  }
}

fn make_valid_update(
  adjacencies: Adjacencies,
  update: Update,
) -> Result(Update, Nil) {
  do_make_update_valid(adjacencies, set.from_list(update.pages), set.new())
  |> result.map(fn(path) { Update(list.reverse(path)) })
}

fn do_make_update_valid(
  adjacencies adjacencies: Adjacencies,
  need needed_pages: set.Set(Page),
  used used_pages: set.Set(Page),
) -> Result(List(Page), Nil) {
  case set.size(needed_pages) {
    0 | 1 -> {
      Ok(set.to_list(needed_pages))
    }

    _ -> {
      needed_pages
      |> set.to_list()
      |> list.find_map(fn(page) {
        try_page_to_make_valid(
          adjacencies:,
          page:,
          need: needed_pages,
          used: used_pages,
        )
      })
    }
  }
}

fn try_page_to_make_valid(
  adjacencies adjacencies: Adjacencies,
  page page: Page,
  need needed_pages: set.Set(Page),
  used used_pages: set.Set(Page),
) -> Result(List(Page), Nil) {
  dict.get(adjacencies, page)
  |> result.map(fn(candidates) {
    case
      set.is_disjoint(candidates, needed_pages)
      || !set.is_empty(set.intersection(used_pages, candidates))
    {
      True -> Error(Nil)
      False ->
        do_make_update_valid(
          adjacencies:,
          need: set.delete(needed_pages, page),
          used: set.insert(used_pages, page),
        )
        |> result.map(fn(path) { [page, ..path] })
    }
  })
  |> result.flatten()
}

fn middle_element(items: List(a)) -> Result(a, Nil) {
  let length = list.length(items)
  let middle_index = length / 2

  items
  |> list.drop(middle_index)
  |> list.first()
}

fn build_adjacencies(page_rules: List(PageRule)) -> Adjacencies {
  list.fold(page_rules, from: dict.new(), with: fn(adjacencies, rule) {
    dict.upsert(adjacencies, rule.first, fn(existing) {
      case existing {
        option.None -> set.from_list([rule.second])
        option.Some(rules) -> set.insert(rules, rule.second)
      }
    })
  })
}

fn parse_input(input: String) -> Result(Input, String) {
  let input_sections =
    input
    |> string.split("\n\n")
    |> list.map(string.trim_end)

  case input_sections {
    [raw_page_rules, raw_updates] -> {
      use rules <- result.try(parse_page_rules(raw_page_rules))
      use updates <- result.try(parse_updates(raw_updates))

      Ok(Input(rules:, updates:))
    }

    _ -> Error("Malformed input; input must have two sections")
  }
}

fn parse_page_rules(input: String) -> Result(List(PageRule), String) {
  input
  |> string.split("\n")
  |> list.try_map(parse_page_rule)
}

fn parse_updates(input: String) -> Result(List(Update), String) {
  input
  |> string.split("\n")
  |> list.try_map(parse_update)
}

fn parse_page_rule(line: String) -> Result(PageRule, String) {
  case string.split(line, "|") {
    [first, second] -> {
      use first <- result.try(parse_int(first))
      use second <- result.try(parse_int(second))

      Ok(PageRule(first:, second:))
    }

    _ -> Error("Malformed page rule; must have two portions")
  }
}

fn parse_update(line: String) -> Result(Update, String) {
  use <- bool.guard(
    string.is_empty(line),
    return: Error("An update cannot have zero pages"),
  )

  line
  |> string.split(",")
  |> list.try_map(parse_int)
  |> result.map(fn(pages) { Update(pages:) })
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Malformed int " <> s })
}

fn try_pop(list list: List(a), or or: b, next next: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> or
    [head, ..rest] -> {
      next(head, rest)
    }
  }
}
