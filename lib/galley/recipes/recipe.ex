defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset
  alias Galley.Recipes, as: R

  schema "recipes" do
    field :source, :string
    field :title, :string
    field :slug, :string
    field :yields, :string
    field :uploaded_images, {:array, :string}, default: []
    belongs_to :user, Galley.Accounts.User
    embeds_one :time, R.RecipeTime, on_replace: :update
    embeds_many :steps, R.RecipeStep, on_replace: :delete
    embeds_many :ingredients, R.RecipeIngredient, on_replace: :delete
    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    # add slug to the mix
    attrs = Map.merge(attrs, slug_map(attrs))

    recipe
    |> cast(attrs, [:title, :source, :yields, :slug, :uploaded_images])
    |> cast_embed(:ingredients)
    |> cast_embed(:steps, with: &R.RecipeStep.changeset/2, required: true)
    |> cast_embed(:time)
    |> validate_required([:title, :yields, :steps, :time, :uploaded_images])
  end

  defp slug_map(%{"title" => title}) do
    %{"slug" => title |> String.downcase() |> String.replace(" ", "-")}
  end

  defp slug_map(_params), do: %{}

  # defp uploaded_images_changeset(schema, params) do
  #   schema |> cast(params, [:url])
  # end
end

## -----------------------------------------------------------------------------

defmodule Galley.Recipes.RecipeStep do
  use Ecto.Schema
  import Ecto.Changeset

  alias Galley.Recipes, as: R

  embedded_schema do
    embeds_one :timer, R.RecipeTime, on_replace: :update
    field :instruction
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:instruction])
    |> cast_embed(:timer)
    |> validate_required([:instruction])
  end
end

## -----------------------------------------------------------------------------

defmodule Galley.Recipes.RecipeIngredient do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :ingredient, :string
    field :quantity, :string
    field :measurement, :string
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:ingredient, :quantity, :measurement])
    |> validate_required([:ingredient, :quantity])
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
