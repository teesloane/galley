defmodule Galley.Repo.Migrations.AddFavouritesTable do
  use Ecto.Migration

  def change do
    create table(:favourite_recipes, primary_key: false) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true

      timestamps()
    end

    # I'm not sure if this is right yet.
    create unique_index(:favourite_recipes, [:recipe_id])
    create index(:favourite_recipes, [:user_id])
  end
end
