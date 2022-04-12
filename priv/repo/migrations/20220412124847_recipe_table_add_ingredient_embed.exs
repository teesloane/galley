defmodule Galley.Repo.Migrations.RecipeTableAddIngredientEmbed do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :ingredients, {:array, :map}, default: []
    end
  end
end
