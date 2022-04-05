defmodule Galley.Recipe.Ingredient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ingredients" do
    field :image, :string
    field :name, :string
    field :style, :string

    timestamps()
  end

  @doc false
  def changeset(ingredient, attrs) do
    ingredient
    |> cast(attrs, [:name, :style, :image])
    |> validate_required([:name, :style, :image])
  end
end
