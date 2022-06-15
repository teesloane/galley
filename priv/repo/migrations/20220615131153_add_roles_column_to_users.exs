defmodule Galley.Repo.Migrations.AddRolesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # possible roles at time of migration: "read-only", "contributor", "admin"
      add :roles, {:array, :string}, default: ["contributor"]
    end
  end
end
