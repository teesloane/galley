defmodule Galley.Repo.Migrations.RecipeTableAddSlug do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :slug, :string
    end
  end
end
