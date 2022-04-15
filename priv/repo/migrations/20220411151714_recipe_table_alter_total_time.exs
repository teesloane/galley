defmodule Galley.Repo.Migrations.RecipeTableAlterTotalTime do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      remove :total_time
      add :time, :map
    end
  end
end
