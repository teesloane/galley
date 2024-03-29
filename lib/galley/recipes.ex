defmodule Galley.Recipes do
  @moduledoc """
  The Recipes context.
  """

  import Ecto.Query, warn: false
  alias Galley.Repo
  alias Ecto.Multi
  alias Mogrify

  alias Galley.Recipes.{Recipe, Tag, Ingredient, Favourite}

  @doc """
  Returns the list of recipes.

  ## Examples

  iex> list_recipes()
  [%Recipe{}, ...]

  """
  def list_recipes do
    Repo.all(Recipe)
    |> Repo.preload(:user)
    |> Repo.preload(:tags)
  end

  def count_recipes do
    Repo.aggregate(Recipe, :count)
  end

  @doc """
  Determine the query we are going to make.
  """
  def search_recipes(params, user_id) do
    from(recipes in Recipe,
      left_join: fav in Favourite,
      as: :favourites,
      on: fav.recipe_id == recipes.id and ^user_id == fav.user_id,
      preload: [favourites: fav]
    )
    |> filter_recipes(params, user_id)
    |> select_for_index()
    |> Repo.all()
    |> Repo.preload(:tags)
  end

  defp filter_recipes(query, params, user_id) do
    Enum.reduce(params, query, fn
      {"tags", ""}, query ->
        query

      {"tags", val}, query ->
        split_tags =
          for tag <- String.split(val, ","),
              tag = tag |> String.trim() |> String.downcase(),
              tag != "",
              do: tag

        # FIXME: This should be optional defp? esp if tagged_recipe_ids is []
        tagged_recipe_ids = get_by_tags(split_tags)

        query |> where([r], r.id in ^tagged_recipe_ids)

      {"query", ""}, query ->
        query

      {"query", val}, query ->
        like = "%#{val}%"
        query |> where([r], like(r.title, ^like))

      {"filter", "My Recipes"}, query ->
        query |> where([r], r.user_id == ^user_id)

      {"filter", "Under an hour"}, query ->
        query
        |> where(
          [r],
          fragment(~s|time->'hour' = '1' and time->'minute' = '0' or time->'hour' < '1'|)
        )

      {"filter", "Under 30 minutes"}, query ->
        query
        |> where(
          [r],
          fragment(~s|time->'hour' < '1' and time->'minute' <= '30'|)
        )

      {"filter", "Recently posted"}, query ->
        query |> where([r], r.inserted_at > ago(2, "week"))

      {"filter", "My favourites"}, query ->
        from([recipes, favourites: fav] in query,
          where: fav.user_id == ^user_id
        )

      {_, _}, query ->
        query
    end)
  end

  defp select_for_index(query) do
    from(r in query,
      order_by: [desc: :inserted_at],
      select: [
        :id,
        :title,
        :slug,
        :time,
        :yields,
        :uploaded_images,
        :ingredients,
        favourites: [:recipe_id, :user_id]
      ]
    )
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

  def get_recipe_by_slug(slug) do
    Repo.get_by(Recipe, slug: slug)
  end

  def get_recipe_by_id_and_slug!(id, slug) do
    Repo.get_by!(Recipe, id: id, slug: slug)
    |> Repo.preload(:user)
    |> Repo.preload(:tags)
  end

  @doc """
  Multi transaction that inserts ingredients and tags to separate table
  and then inserts the recipe.
  After this succeeds, it uploads images to s3 async.
  """
  def insert_recipe(attrs \\ %{}, user, opts \\ []) do
    async_upload = Keyword.get(opts, :async_upload, true)
    attrs = filter_empty_ingredients_and_steps(attrs)

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
      {:ok, %{recipe: recipe}} ->
        unless GalleyUtils.is_test?() do
          if async_upload do
            Task.start(fn -> compress_and_upload_s3(recipe) end)
          else
            compress_and_upload_s3(recipe)
          end
        end

        {:ok, recipe}

      {:error, :recipe, changeset, _} ->
        {:error, changeset}
    end
  end

  def update_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    attrs = filter_empty_ingredients_and_steps(attrs)

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
      {:ok, %{recipe: recipe}} ->
        unless GalleyUtils.is_test?() do
          Task.start(fn -> compress_and_upload_s3(recipe) end)
        end

        {:ok, recipe}

      {:error, :recipe, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Adds a recipe to a user's favourites if it doesn't exist.
  If it does exist, remove it from the user's favourites.

  ## Examples

  iex> favourite_recipe(%{
  user_id: user.id,
  recipe_id: recipe.id
  })

  => [%Recipe{}, ...]
  """
  def favourite_recipe(attrs) do
    %Favourite{}
    |> Favourite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Remove recipes from user's favourites
  """
  def unfavourite_recipe(attrs) do
    %Favourite{recipe_id: attrs.recipe_id, user_id: attrs.user_id}
    |> Repo.delete()
  end

  def is_favourite?(%{user_id: user_id, recipe_id: recipe_id}) do
    query = from(f in Favourite, where: f.user_id == ^user_id and f.recipe_id == ^recipe_id)
    Repo.all(query) |> Enum.count() > 0
  end

  defp parse_tags(nil), do: []

  defp parse_tags(tags) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    for tag <- String.split(tags, ","),
        tag = tag |> String.trim() |> String.downcase(),
        tag != "",
        do: %{name: tag, inserted_at: now, updated_at: now}
  end

  # fetches tags from form and makes them into maps then upserts them.
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
        # if GalleyUtils.is_prod?() do
        Enum.each(deleted_recipe.uploaded_images, fn image ->
          delete_image_on_s3(image)
        end)

        # end

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
          Task.start(fn -> delete_image_on_s3(image) end)
        end

        image.id != photo_id
      end)

    recipe
    |> change_recipe()
    |> Ecto.Changeset.put_embed(:uploaded_images, filtered_photos)
    |> Repo.update()
  end

  # delete the full image and thumbnail for a recipe.
  defp delete_image_on_s3(image) do
    bucket = Galley.Application.get_bucket()
    _x = ExAws.S3.delete_object(bucket, image.key_s3) |> ExAws.request()

    _y =
      ExAws.S3.delete_object(bucket, GalleyUtils.get_thumbnail(image.key_s3))
      |> ExAws.request()

    # IO.inspect({y, image}, label: "[log - s3]: deleted image thumbnail")
  end

  def delete_all_images_on_s3() do
    x = IO.gets("Do you want to delete all s3 assets? ") |> String.trim()
    bucket = Galley.Application.get_bucket()

    if x == "y" do
      stream =
        ExAws.S3.list_objects(bucket)
        |> ExAws.stream!()
        |> Stream.map(& &1.key)

      ExAws.S3.delete_all_objects(bucket, stream) |> ExAws.request()
    end
  end

  def delete_all_recipes() do
    x = IO.gets("Do you want to delete all recipes? ") |> String.trim()

    if x == "y" do
      Repo.delete_all(Recipe)
    end
  end

  def delete_all_images_in_static() do
    dir = Galley.Application.get_uploads_folder()

    x = IO.gets("Do you want to delete all static_assets? ") |> String.trim()

    if x == "y" do
      uploads = Path.wildcard("#{dir}/*")

      uploads
      |> Enum.each(fn e -> File.rm(e) end)
    end
  end

  def delete_recipes_local_and_s3_images() do
    delete_all_images_in_static()
  end

  def delete_all_recipes_and_associated() do
    delete_all_images_in_static()
    delete_all_images_on_s3()
    delete_all_recipes()
  end

  def compress_and_upload_s3(recipe) do
    bucket = Galley.Application.get_bucket()

    # little lambda to do the uploading later.
    upload_file = fn {src_path, dest_path} ->
      z =
        ExAws.S3.put_object(bucket, dest_path, File.read!(src_path))
        |> ExAws.request!()

      IO.inspect(z, label: "[log - s3]: put object")
    end

    # we use reduce so we can update the old images and build up a map
    # of images to upload in a single iteration.
    # We also happen to do the compression in this function, but that could be done elsewhere if necessary.
    image_data =
      Enum.reduce(recipe.uploaded_images, %{updated_images: [], s3_uploads: %{}}, fn img, acc ->
        if img.is_local && String.length(img.local_path) > 0 do
          full_file = img.local_path
          aws_dir = "https://#{bucket}.s3-ca-central-1.amazonaws.com"
          thumb_file = GalleyUtils.get_thumbnail(full_file)

          s3_dest = fn f ->
            "/public/recipes_imgs/#{Path.basename(f)}"
          end

          # resize images
          Mogrify.open(full_file)
          |> Mogrify.resize_to_fill("450x300")
          |> Mogrify.save(path: thumb_file)

          Mogrify.open(full_file)
          |> Mogrify.resize_to_limit("1800")
          |> Mogrify.save(path: full_file)

          # update the original image with the s3 urls.
          updated_original = %{
            img
            | url: "#{aws_dir}#{s3_dest.(full_file)}",
              url_thumb: "#{aws_dir}#{s3_dest.(thumb_file)}",
              local_path: "",
              is_local: false,
              key_s3: s3_dest.(full_file)
          }

          # desired result: %{"path/to/src0" => "path/to/dest0", "path/to/src1" => "path/to/dest1"}
          s3_uploads =
            acc.s3_uploads
            |> Map.put(img.local_path, s3_dest.(img.local_path))
            |> Map.put(thumb_file, s3_dest.(thumb_file))

          %{
            acc
            | updated_images: [Map.from_struct(updated_original) | acc.updated_images],
              s3_uploads: s3_uploads
          }
        end
      end)

    if image_data do
      res =
        image_data.s3_uploads
        |> Task.async_stream(upload_file, max_concurrency: 1, timeout: 25000)
        |> Stream.run()

      if res == :ok do
        updated_recipe =
          recipe
          |> change_recipe(%{uploaded_images: image_data.updated_images})
          |> Repo.update()

        case updated_recipe do
          {:ok, new_recipe} ->
            # delete local images
            Enum.each(recipe.uploaded_images, fn img ->
              File.rm!(img.local_path)
              File.rm!(GalleyUtils.get_thumbnail(img.local_path))
            end)

            {:ok, new_recipe}

          {:error, :recipe, changeset, _} ->
            {:error, changeset}
        end
      end
    end
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

  defp filter_empty_ingredients_and_steps(attrs) do
    attrs
    |> Map.update!("steps", fn i ->
      Enum.reject(i, fn {_, val} -> val["instruction"] === "" end)
      |> Enum.into(%{})
    end)
    |> Map.update!("ingredients", fn i ->
      Enum.reject(i, fn {_, val} -> val["ingredient"] === "" end)
      |> Enum.into(%{})
    end)
  end
end
