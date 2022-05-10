defmodule Galley.Recipes.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
