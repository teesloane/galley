defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipes" do
    field :source, :string
    field :title, :string
    field :yields, :string
    embeds_many :steps, Galley.Recipes.RecipeStep, on_replace: :delete
    embeds_one :time, Galley.Recipes.RecipeTime, on_replace: :update

    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:title, :source, :yields])
    |> validate_required([:title, :yields])
    |> cast_embed(:steps)
    |> cast_embed(:time)
  end

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
