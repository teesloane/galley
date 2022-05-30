defmodule Galley.Repo.Migrations.AddUploadedImagesToRecipes do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :uploaded_images, {:array, :map}, default: []
    end
  end
end
