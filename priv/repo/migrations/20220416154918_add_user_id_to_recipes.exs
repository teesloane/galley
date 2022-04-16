defmodule Galley.Repo.Migrations.AddUserIdToRecipes do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :user_id, references(:users)
    end
  end
end
