defmodule Galley.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset
  alias Galley.Recipes, as: R

  schema "recipes" do
    field(:source, :string)
    field(:title, :string)
    field(:slug, :string)
    field(:yields, :string)
    field(:notes, :string)
    belongs_to(:user, Galley.Accounts.User)
    embeds_one(:time, R.RecipeTime, on_replace: :update)

    embeds_many :uploaded_images, Image, on_replace: :delete do
      field(:url, :string)
      field(:url_thumb, :string)
      field(:is_hero, :boolean, default: false)
      field(:key_s3, :string)
      field(:is_local, :boolean, default: true)
      field(:local_path, :string)
    end

    embeds_many :ingredients, Ingredient, on_replace: :delete do
      field(:ingredient, :string)
      field(:quantity, :string)
      field(:measurement, :string)
      field(:prep, :string)
      field(:temp_id, :string, virtual: true)
    end

    embeds_many :steps, Step, on_replace: :delete do
      embeds_one(:timer, R.RecipeTime, on_replace: :update)
      field(:instruction)
      field(:temp_id, :string, virtual: true)
    end

    has_many(:favourites, Galley.Recipes.Favourite)
    many_to_many(:tags, R.Tag, join_through: "recipes_tags", on_replace: :delete)

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
    |> validate_embed_min_one_key(:ingredients, :ingredient, "Missing ingredient")
    |> validate_embed_min_one_key(:steps, :instruction, "Missing instruction on steps")
    |> validate_required([:title, :yields, :steps, :time, :uploaded_images])
    |> validate_length(:notes, min: 0, max: 400)
  end

  defp slug_map(%{"title" => title}) do
    %{"slug" => title |> String.downcase() |> String.replace(" ", "-")}
  end

  defp slug_map(_params), do: %{}

  defp uploaded_images_changeset(schema, params) do
    schema |> cast(params, [:url, :url_thumb, :is_hero, :key_s3, :is_local, :local_path])
  end

  @doc """
  we don't validate_required on :ingredient here because
  we want it to be possible for users to submit the form with empty ingredient fields
  (for example, when the form loads, there might be 5 empty fields to fill in
  but they only use 3 - they shouldn't have to delete empty fields in order
  to submit the form.)
  """
  def ingredient_changeset(ingredient, attrs) do
    ingredient
    |> Map.put(:temp_id, ingredient.temp_id || attrs["temp_id"])
    |> cast(attrs, [:ingredient, :quantity, :measurement, :prep])
  end

  def step_changeset(step, attrs) do
    step
    |> Map.put(:temp_id, step.temp_id || attrs["temp_id"])
    |> cast(attrs, [:instruction])
    |> cast_embed(:timer)
  end

  # used to validate that at least one ingredient/instruciton is filled in
  # (since we strip all empty fields on insert.)
  def validate_embed_min_one_key(changeset, field, subkey, msg) do
    validate_change(changeset, field, fn field, value ->
      has_min_one_ingredient =
        Enum.any?(value, fn val ->
          is_nil(Map.get(val.changes, subkey)) == false
        end)

      if has_min_one_ingredient do
        []
      else
        [{field, msg}]
      end
    end)
  end
end

defmodule Galley.Recipes.RecipeTime do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:hour, :integer)
    field(:minute, :integer)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:hour, :minute])
    |> validate_required([:hour, :minute])
  end
end
