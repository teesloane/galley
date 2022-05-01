defmodule Galley.Recipes do
  @moduledoc """
  The Recipes context.
  """

  import Ecto.Query, warn: false
  alias Galley.Repo

  alias Galley.Recipes.Recipe, as: Recipe

  @doc """
  Returns the list of recipes.

  ## Examples

      iex> list_recipes()
      [%Recipe{}, ...]

  """
  def list_recipes do
    Repo.all(Recipe)
    |> Repo.preload(:user)
  end

  @doc """
  Search recipes is a bit complex because there are multiple cases we need
  to handle for when we dispatch the DB query.
  """
  def search_recipes(%{"filter" => filter, "query" => query, "tags" => _tags}, user_id) do
    cond do
      filter == "All" and query == "" ->
        list_recipes()

      filter == "All" and query != "" ->
        from(r in Recipe, where: ilike(r.title, ^"%#{query}%"))
        |> Repo.all()
        |> Repo.preload(:user)

      filter == "My Recipes" and query == "" ->
        from(r in Recipe, where: r.user_id == ^user_id)
        |> Repo.all()
        |> Repo.preload(:user)

      filter == "My Recipes" and query != "" ->
        Recipe
        |> where([r], r.user_id == ^user_id)
        |> where([r], ilike(r.title, ^"%#{query}%"))
        |> Repo.all()
        |> Repo.preload(:user)

      filter == "My Recipes" and query != "" ->
        from(r in Recipe, where: ilike(r.title, ^"%#{query}%"))
        |> Repo.all()
        |> Repo.preload(:user)

      true ->
        list_recipes()
    end
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
  def get_recipe!(id) do
    Repo.get!(Recipe, id) |> Repo.preload(:user)
  end

  def get_recipe_by_id_and_slug!(id, slug) do
    Repo.get_by!(Recipe, id: id, slug: slug)
    |> Repo.preload(:user)
  end

  @doc """
  Creates a recipe.

  ## Examples

      iex> create_recipe(%{field: value})
      {:ok, %Recipe{}}

      iex> create_recipe(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_recipe(user, attrs \\ %{}) do
    # FIXME:  this should be in a transaction, I think.
    upsert_ingredient(attrs)

    ## add the user id!
    %Recipe{user_id: user.id}
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

  def delete_recipe_step(%Recipe{} = recipe, step_id) do
    filtered_steps = recipe.steps |> Enum.filter(fn step -> step.id != step_id end)

    recipe
    |> change_recipe()
    |> Ecto.Changeset.put_embed(:steps, filtered_steps)
    |> Repo.update()
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

  def change_step(%Recipe.Step{} = recipe_step, attrs \\ %{}) do
    Recipe.step_changeset(recipe_step, attrs)
  end

  def change_ingredient(%Recipe.Ingredient{} = recipe_ingredient, attrs \\ %{}) do
    Recipe.ingredient_changeset(recipe_ingredient, attrs)
  end

  defp upsert_ingredient(attrs) do
    attrs["ingredients"]
    |> Map.values()
    |> Enum.each(fn %{"ingredient" => x} ->
      %Recipe.Ingredient{} |> Recipe.ingredient_changeset(%{name: x}) |> Repo.insert(on_conflict: :nothing)
    end)
  end
end
