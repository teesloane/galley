defmodule Galley.Recipes do
  @moduledoc """
  The Recipes context.
  """

  import Ecto.Query, warn: false
  alias Galley.Repo
  alias Ecto.Multi
  alias Mogrify

  alias Galley.Recipes.{Recipe, Tag, Ingredient}

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
  Determine the query we are going to make.
  """
  def search_recipes(%{"filter" => filter, "query" => search_query, "tags" => tags}, user_id) do
    s_conditions =
      if search_query !== "",
        do: dynamic([r], like(r.title, ^"%#{search_query}%")),
        else: true

    f_conditions =
      if filter === "My Recipes",
        do: dynamic([r], r.user_id == ^user_id),
        else: true

    and_condition = dynamic([s], ^s_conditions and ^f_conditions)

    if String.length(tags) === 0 do
      from(r in Recipe) |> where([s], ^and_condition) |> Repo.all()
    else
      split_tags =
        for tag <- String.split(tags, ","),
            tag = tag |> String.trim() |> String.downcase(),
            tag != "",
            do: tag

      tagged_recipe_ids = get_by_tags(split_tags)

      from(r in Recipe)
      |> where([s], ^and_condition)
      |> where([r], r.id in ^tagged_recipe_ids)
      |> Repo.all()
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
      {:ok, repo.all(from(t in Tag, where: t.name in ^tag_names))}
    end)
  end

  defp upsert_ingredient(multi, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # NOTE: the difference between Ingrdient here (Recipes.Ingredient) and
    # Recipe.Ingredient (which is generated automatically as an embedded_schema)
    ingrs =
      attrs["ingredients"]
      |> Map.values()
      |> Enum.map(fn ingrMap ->
        %{name: ingrMap["ingredient"], inserted_at: now, updated_at: now}
      end)

    multi
    |> Multi.insert_all(:insert_ingredients, Ingredient, ingrs, on_conflict: :nothing)
  end

  def delete_recipe(%Recipe{} = recipe) do
    case Repo.delete(recipe) do
      {:ok, deleted_recipe} ->
        if GalleyUtils.is_prod?() do
          Enum.each(deleted_recipe.uploaded_images, fn image ->
            delete_image_on_s3(image)
          end)
        end

        {:ok, deleted_recipe}

      {:error, changeset} ->
        {:error, changeset}
    end
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
      |> Enum.filter(fn image ->
        # NOTE: side effect - let's delete the image in s3 (optimistically)
        if image.id == photo_id do
          delete_image_on_s3(image)
        end

        image.id != photo_id
      end)

    recipe
    |> change_recipe()
    |> Ecto.Changeset.put_embed(:uploaded_images, filtered_photos)
    |> Repo.update()
  end

  defp delete_image_on_s3(image) do
    ExAws.S3.delete_object("theiceshelf-galley", image.key_s3) |> ExAws.request()
  end

  # defp move_local_imgs_to_s3(recipe) do
  #   # full_file = recipe.
  #   Enum.each(recipe.uploaded_images, fn img ->
  #     client_name = entry.client_name |> String.replace(" ", "_")
  #     uploads_dir = Galley.Application.get_uploads_folder()
  #     thumb_file = Path.join([uploads_dir, "thumb_#{Path.basename(path)}_#{client_name}"])
  #     # resize images
  #     open(full_file) |> resize_to_fill("450x300") |> save(path: thumb_file)
  #     open(full_file) |> resize_to_limit("1800") |> save(path: full_file)

  #     make_key = fn f_name ->
  #       "public/recipes_imgs/#{Path.basename(f_name)}"
  #     end

  #     base_url = "https://theiceshelf-galley.s3.ca-central-1.amazonaws.com"

  #     full_upload =
  #       ExAws.S3.put_object(
  #         "theiceshelf-galley",
  #         make_key.(full_file),
  #         File.read!(full_file)
  #       )
  #       |> ExAws.request()

  #     thumb_upload =
  #       ExAws.S3.put_object(
  #         "theiceshelf-galley",
  #         make_key.(thumb_file),
  #         File.read!(thumb_file)
  #       )
  #       |> ExAws.request()
  #   end)
  # end

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
  Recieves a list of tags and queries recipes that have that tag.
  """
  def get_by_tags(tag_list) do
    q =
      from(tags in Tag,
        join: recipe_tags in Galley.Recipes.RecipeTag,
        on: recipe_tags.tag_id == tags.id,
        # tag must be in the tag_list
        where: tags.name in ^tag_list,
        # get just recipe ids
        select: recipe_tags.recipe_id,
        # remove duplicate ids
        group_by: recipe_tags.recipe_id
      )

    Repo.all(q)
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
end
