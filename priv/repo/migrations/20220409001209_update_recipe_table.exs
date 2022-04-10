defmodule Galley.Repo.Migrations.UpdateRecipeTable do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :steps, {:array, :map}, default: []
    end
  end
end
