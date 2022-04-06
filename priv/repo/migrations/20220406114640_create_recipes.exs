defmodule Galley.Repo.Migrations.CreateRecipes do
  use Ecto.Migration

  def change do
    create table(:recipes) do
      add :title, :string
      add :source, :string
      add :author, :string
      add :cook_time, :string
      add :prep_time, :string
      add :total_time, :string
      add :yields, :string

      timestamps()
    end
  end
end
