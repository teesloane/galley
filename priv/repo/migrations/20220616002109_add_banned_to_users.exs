defmodule Galley.Repo.Migrations.AddBannedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:banned, :boolean, default: false)
    end
  end
end
