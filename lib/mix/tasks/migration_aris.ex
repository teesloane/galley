defmodule Mix.Tasks.Db.MigrateAris do
  use Mix.Task
  import Mogrify

  @requirements ["app.start"]
  @shortdoc "Migrate from Ari's garden"
  @spec run(any) :: any
  def run(_) do
    Galley.Recipes.MigrateAris.do_migration()
  end
end
