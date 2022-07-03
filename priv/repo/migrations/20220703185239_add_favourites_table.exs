defmodule Galley.Repo.Migrations.AddFavouritesTable do
  use Ecto.Migration

  def change do
    create table(:favourite_recipes) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true

      # I'm not sure if this is right yet.
      create index(:favourite_recipes, [:recipe_id])
      create index(:favourite_recipes, [:user_id])
    end
  end
end
