defmodule Galley.Recipes do
  @moduledoc """
  The Recipes context.
  """

  import Ecto.Query, warn: false
  alias Galley.Repo

  alias Galley.Recipes.Recipe
  alias Galley.Recipes.Ingredient
  alias Galley.Recipes

  @doc """
  Returns the list of recipes.

  ## Examples

      iex> list_recipes()
      [%Recipe{}, ...]

  """
  def list_recipes do
    Repo.all(Recipe)
  end

  @doc """
  Gets a single recipe.

  Raises `Ecto.NoResultsError` if the Recipe does not exist.

  ## Examples

      iex> get_recipe!(123)
      %Recipe{}

      iex> get_recipe!(456)
      ** (Ecto.NoResultsError)

  """
  def get_recipe!(id), do: Repo.get!(Recipe, id)

  def get_recipe_by_id_and_slug!(id, slug), do: Repo.get_by!(Recipe, id: id, slug: slug)

  @doc """
  Creates a recipe.

  ## Examples

      iex> create_recipe(%{field: value})
      {:ok, %Recipe{}}

      iex> create_recipe(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_recipe(attrs \\ %{}) do
    upsert_ingredient(attrs)

    %Recipe{}
    |> Recipe.changeset(attrs)
    |> Repo.insert()
  end

  def create_ingredients(ingredients \\ [%{}]) do
    Repo.insert_all(Ingredient, ingredients)
  end

  @doc """
  Updates a recipe.

  ## Examples

      iex> update_recipe(recipe, %{field: new_value})
      {:ok, %Recipe{}}

      iex> update_recipe(recipe, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_recipe(%Recipe{} = recipe, attrs) do
    upsert_ingredient(attrs)

    recipe
    |> Recipe.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a recipe.

  ## Examples

      iex> delete_recipe(recipe)
      {:ok, %Recipe{}}

      iex> delete_recipe(recipe)
      {:error, %Ecto.Changeset{}}

  """
  def delete_recipe(%Recipe{} = recipe) do
    Repo.delete(recipe)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking recipe changes.

  ## Examples

      iex> change_recipe(recipe)
      %Ecto.Changeset{data: %Recipe{}}

  """
  def change_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  def change_step(%Recipes.RecipeStep{} = recipe_step, attrs \\ %{}) do
    Recipes.RecipeStep.changeset(recipe_step, attrs)
  end

  def change_ingredient(%Recipes.RecipeIngredient{} = recipe_ingredient, attrs \\ %{}) do
    Recipes.RecipeIngredient.changeset(recipe_ingredient, attrs)
  end

  defp upsert_ingredient(attrs) do
    attrs["ingredients"]
    |> Map.values()
    |> Enum.each(fn %{"ingredient" => x} ->
      %Ingredient{} |> Ingredient.changeset(%{name: x}) |> Repo.insert(on_conflict: :nothing)
    end)
  end
end
