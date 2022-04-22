defmodule Galley.Repo.Migrations.ChangeUploadedImagesRecipesToMap do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      remove :uploaded_images
      # couldn't  convert to the below so I just remove the column.
      add :uploaded_images, {:array, :map}, default: []
    end
  end
end
