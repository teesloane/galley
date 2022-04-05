defmodule Galley.Repo.Migrations.CreateIngredients do
  use Ecto.Migration

  def change do
    create table(:ingredients) do
      add :name, :string
      add :style, :string
      add :image, :string

      timestamps()
    end
  end
end
