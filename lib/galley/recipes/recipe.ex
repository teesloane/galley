defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipes" do
    field :author, :string
    field :cook_time, :string
    field :prep_time, :string
    field :source, :string
    field :title, :string
    field :total_time, :string
    field :yields, :string
    embeds_many :steps, Galley.Recipes.RecipeStep, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:title, :source, :author, :cook_time, :prep_time, :total_time, :yields])
    |> validate_required([:title, :source, :author, :cook_time, :prep_time, :total_time, :yields])
    |> cast_embed(:steps)
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
    |>cast(attrs, [:timer, :instruction])
  end
end
