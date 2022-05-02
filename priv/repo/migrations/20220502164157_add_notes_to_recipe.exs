defmodule Galley.Repo.Migrations.AddNotesToRecipe do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :notes, :text
    end

  end
end
