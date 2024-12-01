import argv
import gleam/io
import gleave
import glint

pub fn main() {
  io.println("Usage: gleam run -m day<n> <filename>")
  gleave.exit(1)
}

pub fn run_with_input_file(run: fn(String) -> Nil) {
  glint.new()
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: run_command(run))
  |> glint.run(argv.load().arguments)
}

fn run_command(run: fn(String) -> Nil) -> glint.Command(Nil) {
  use filename_arg <- glint.named_arg("filename")
  use named, _unnamed, _flags <- glint.command()

  run(filename_arg(named))
}
