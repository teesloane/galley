defmodule Galley.Repo.Migrations.CreateIngredients do
  use Ecto.Migration

  def change do
    create table(:ingredients) do
      add :name, :string
      add :image, :string
      add :style, :string

      timestamps()
    end
  end
end
