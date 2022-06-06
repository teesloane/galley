defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset
  alias Galley.Recipes, as: R

  schema "recipes" do
    field :source, :string
    field :title, :string
    field :slug, :string
    field :yields, :string
    field :notes, :string
    belongs_to :user, Galley.Accounts.User
    embeds_one :time, R.RecipeTime, on_replace: :update

    embeds_many :uploaded_images, Image, on_replace: :delete do
      field :url, :string
      field :is_hero, :boolean, default: false
      field :key_s3, :string
    end

    embeds_many :ingredients, Ingredient, on_replace: :delete do
      field :ingredient, :string
      field :quantity, :string
      field :measurement, :string
      field :temp_id, :string, virtual: true
    end

    embeds_many :steps, Step, on_replace: :delete do
      embeds_one :timer, R.RecipeTime, on_replace: :update
      field :instruction
      field :temp_id, :string, virtual: true
    end

    many_to_many :tags, Galley.Recipes.Tag, join_through: "recipes_tags", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    # add slug to the mix
    attrs = Map.merge(attrs, slug_map(attrs))

    recipe
    |> cast(attrs, [:title, :source, :yields, :slug, :notes])
    |> cast_embed(:ingredients, with: &ingredient_changeset/2, required: true)
    |> cast_embed(:uploaded_images, with: &uploaded_images_changeset/2)
    |> cast_embed(:steps, with: &step_changeset/2, required: true)
    |> cast_embed(:time)
    |> validate_required([:title, :yields, :steps, :time, :uploaded_images])
    |> validate_length(:notes, min: 0, max: 400)
  end

  defp slug_map(%{"title" => title}) do
    %{"slug" => title |> String.downcase() |> String.replace(" ", "-")}
  end

  defp slug_map(_params), do: %{}

  defp uploaded_images_changeset(schema, params) do
    schema |> cast(params, [:url, :is_hero, :key_s3])
  end

  def ingredient_changeset(ingredient, attrs) do
    ingredient
    |> Map.put(:temp_id, (ingredient.temp_id || attrs["temp_id"]))
    |> cast(attrs, [:ingredient, :quantity, :measurement])
    |> validate_required([:ingredient, :quantity])
  end


  def step_changeset(step, attrs) do
    step
    |> Map.put(:temp_id, (step.temp_id || attrs["temp_id"]))
    |> cast(attrs, [:instruction])
    |> cast_embed(:timer)
    |> validate_required([:instruction])
  end
end

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
