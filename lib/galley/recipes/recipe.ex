defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset
  alias Galley.Recipes, as: R

  schema "recipes" do
    field :source, :string
    field :title, :string
    field :slug, :string
    field :yields, :string
    embeds_many :steps, R.RecipeStep, on_replace: :delete
    embeds_many :ingredients, R.RecipeIngredient, on_replace: :delete
    embeds_one :time, R.RecipeTime, on_replace: :update

    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    attrs = Map.merge(attrs, slug_map(attrs)) # add slug to the mix

    recipe
    |> cast(attrs, [:title, :source, :yields, :slug])
    |> cast_embed(:ingredients)
    |> cast_embed(:steps)
    |> cast_embed(:time)
    |> validate_required([:title, :yields, :steps, :time])

    # |> validate_length(:steps, min: 1) # I don't think this is working.
  end

  defp slug_map(%{"title" => title}) do
    %{"slug" => title |> String.downcase() |> String.replace(" ", "-")}
  end

  defp slug_map(_params), do: %{}
end

## -----------------------------------------------------------------------------

defmodule Galley.Recipes.RecipeStep do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :timer
    field :instruction
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:timer, :instruction])
  end
end

## -----------------------------------------------------------------------------

defmodule Galley.Recipes.RecipeIngredient do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :ingredient, :string
    field :quantity, :float
    field :measurement, :string
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:ingredient, :quantity, :measurement])
  end
end

## -----------------------------------------------------------------------------

defmodule Galley.Recipes.RecipeTime do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :hour, :integer
    field :minute, :integer
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:hour, :minute])
    |> validate_required([:hour, :minute])
  end
end
