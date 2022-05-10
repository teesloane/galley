defmodule Galley.Repo.Migrations.CreateRecipesTags do
  use Ecto.Migration

  def change do
    create table(:recipes_tags, primary_key: false) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), primary_key: true
      add :tag_id, references(:tags, on_delete: :nothing), primary_key: true
    end

    create index(:recipes_tags, [:recipe_id])
    create index(:recipes_tags, [:tag_id])
  end
end
