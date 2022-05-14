defmodule Galley.Recipes do
  @moduledoc """
  The Recipes context.
  """

  import Ecto.Query, warn: false
  alias Galley.Repo
  alias Ecto.Multi

  alias Galley.Recipes.{Recipe, Tag, RecipeTag, Ingredient}

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
    Repo.get!(Recipe, id) |> Repo.preload(:user) |> Repo.preload(:tags)
  end

  def get_recipe_by_id_and_slug!(id, slug) do
    Repo.get_by!(Recipe, id: id, slug: slug)
    |> Repo.preload(:user)
    |> Repo.preload(:tags)
  end

  def insert_recipe(user, attrs \\ %{}) do
    multi_result =
      Multi.new()
      |> insert_and_get_tags(attrs)
      |> upsert_ingredient(attrs)
      |> Multi.insert(:recipe, fn %{tags: tags} ->
        %Recipe{user_id: user.id}
        |> Recipe.changeset(attrs)
        |> Ecto.Changeset.put_assoc(:tags, tags)
      end)
      |> Repo.transaction()

    case multi_result do
      {:ok, %{recipe: recipe}} -> {:ok, recipe}
      {:error, :recipe, changeset, _} -> {:error, changeset}
    end
  end

  def update_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    multi_result =
      Multi.new()
      |> insert_and_get_tags(attrs)
      |> upsert_ingredient(attrs)
      |> Multi.update(:recipe, fn %{tags: tags} ->
        recipe
        |> Recipe.changeset(attrs)
        |> Ecto.Changeset.put_assoc(:tags, tags)
      end)
      |> Repo.transaction()

    case multi_result do
      {:ok, %{recipe: recipe}} -> {:ok, recipe}
      {:error, :recipe, changeset, _} -> {:error, changeset}
    end
  end

  defp parse_tags(nil), do: []

  defp parse_tags(tags) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    for tag <- String.split(tags, ","),
        tag = tag |> String.trim() |> String.downcase(),
        tag != "",
        do: %{name: tag, inserted_at: now, updated_at: now}
  end

  # fetches tags from form and makes them into maps.
  # then upserts them,
  defp insert_and_get_tags(multi, attrs) do
    tags = parse_tags(attrs["tags"])

    multi
    |> Multi.insert_all(:insert_tags, Tag, tags, on_conflict: :nothing)
    |> Multi.run(:tags, fn repo, _changes ->
      tag_names = for t <- tags, do: t.name
      {:ok, repo.all(from t in Tag, where: t.name in ^tag_names)}
    end)
  end


  defp upsert_ingredient(multi, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # NOTE: the difference between Ingrdient here (Recipes.Ingredient) and
    # Recipe.Ingredient (which is generated automatically as an embedded_schema)
    ingrs = attrs["ingredients"]
    |> Map.values()
    |> Enum.map(fn ingrMap ->
      %{name: ingrMap["ingredient"],
        inserted_at: now,
        updated_at: now
       }
    end)

    multi
    |> Multi.insert_all(:insert_ingredients, Ingredient, ingrs, on_conflict: :nothing)
  end


  @doc """
  Updates a recipe.

  ## Examples

      iex> update_recipe(recipe, %{field: new_value})
      {:ok, %Recipe{}}

      iex> update_recipe(recipe, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  # def update_recipe(%Recipe{} = recipe, attrs) do
  #   # upsert_ingredient(attrs)

  #   recipe
  #   |> Recipe.changeset(attrs)
  #   |> Repo.update()
  # end

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

  def delete_ingredient_photo(%Recipe{} = recipe, photo_id) do
    filtered_photos =
      recipe.uploaded_images
      |> Enum.filter(fn image -> image.id != photo_id end)

    # TODO: figure out how to delete the image in storage.
    recipe
    |> change_recipe()
    |> Ecto.Changeset.put_embed(:uploaded_images, filtered_photos)
    |> Repo.update()
  end

  def delete_ingredient_step(%Recipe{} = recipe, ingredient_id) do
    filtered_ingredient =
      recipe.ingredients
      |> Enum.filter(fn ingr -> ingr.id != ingredient_id end)

    recipe
    |> change_recipe()
    |> Ecto.Changeset.put_embed(:ingredients, filtered_ingredient)
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

  # defp upsert_ingredient(attrs) do
  #   attrs["ingredients"]
  #   |> Map.values()
  #   |> Enum.each(fn %{"ingredient" => x} ->
  #     %Recipe.Ingredient{}
  #     |> Recipe.ingredient_changeset(%{name: x})
  #     |> Repo.insert(on_conflict: :nothing)
  #   end)
  # end
end
