defmodule Galley.Recipes.Favourite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "favourite_recipes" do
    field(:recipe_id, :id, primary_key: true)
    field(:user_id, :id, primary_key: true)
    timestamps()
  end

  def changeset(favourite, attrs) do
    favourite
    |> cast(attrs, [:user_id, :recipe_id])
    |> validate_required([:user_id, :recipe_id])
  end
end
