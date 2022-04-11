defmodule Galley.Repo.Migrations.RecipeTableRemoveAuthor do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      remove :author
    end

  end
end
