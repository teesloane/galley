defmodule Galley.Repo.Migrations.RecipeTableRemoveTimeFields do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      remove :cook_time
      remove :prep_time
    end
  end
end
