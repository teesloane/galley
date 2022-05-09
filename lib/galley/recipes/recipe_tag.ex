defmodule Galley.Recipes.RecipeTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipes_tags" do

    field :recipe_id, :id
    field :tag_id, :id

    timestamps()
  end

  @doc false
  def changeset(recipe_tag, attrs) do
    recipe_tag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
