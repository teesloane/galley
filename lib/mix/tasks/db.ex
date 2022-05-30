defmodule Mix.Tasks.Db.Reset do
  use Mix.Task

  @shortdoc "Drop db -> re-setup -> migrate -> seed"
  def run(_) do
    Mix.Task.run("ecto.drop")
    Mix.Task.run("ecto.setup")
    Mix.Task.run("ecto.migrate")
  end
end
