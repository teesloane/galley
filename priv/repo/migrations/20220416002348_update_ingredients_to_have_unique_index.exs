defmodule Galley.Repo.Migrations.UpdateIngredientsToHaveUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index(:ingredients, [:name])
  end
end
