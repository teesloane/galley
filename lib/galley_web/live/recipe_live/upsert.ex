defmodule GalleyWeb.RecipeLive.Upsert do
  use GalleyWeb, :live_view

  alias Galley.Recipes
  alias Galley.Recipes.Recipe, as: Recipe

  @doc """
  In this mount we need to assign both the original base recipe
  and the changeset, as sometimes we need access to the original
  data from the recipe struct after the changeset has started to change.
  """
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_images, [])
     |> assign(:return_to, Routes.recipe_index_path(socket, :index))
     |> assign(:recipe, build_base_recipe())
     |> assign(:changeset, build_base_recipe() |> Recipes.change_recipe())
     |> assign(:selected_hero, 0)
     |> assign(:__add_n_ingredients, 1)
     |> assign(:__add_n_steps, 1)
     |> allow_upload(:recipe_img,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 4
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    action = socket.assigns.live_action
    u = socket.assigns.current_user
    u_id = u.id

    case action do
      :new ->
        {:noreply, apply_action(socket, action, params)}

      :edit ->
        recipe = Recipes.get_recipe!(params["id"])

        cond do
          u_id == recipe.user.id ->
            {:noreply, apply_action(socket, action, params, recipe)}

          Galley.Accounts.is_admin?(u) ->
            {:noreply, apply_action(socket, action, params, recipe)}

          true ->
            {:noreply, socket |> push_redirect(to: Routes.recipe_index_path(socket, :index))}
        end
    end
  end

  defp build_base_recipe() do
    ingrs =
      for _n <- 0..4,
          do: %Recipe.Ingredient{
            temp_id: GalleyUtils.get_temp_id(),
            quantity: "",
            measurement: "",
            ingredient: ""
          }

    steps =
      for _n <- 0..4,
          do: %Recipe.Step{temp_id: GalleyUtils.get_temp_id(), timer: nil, instruction: nil}

    %Recipe{
      ingredients: ingrs,
      steps: steps,
      uploaded_images: [],
      tags: []
    }
  end

  # This is how we set the form to work for either :edit or :new
  defp apply_action(socket, :edit, %{"id" => _id}, recipe) do
    selected_hero = get_current_hero_idx(socket.assigns.uploads, recipe)

    socket
    |> assign(:page_title, "Edit - #{recipe.title}")
    |> assign(:recipe, recipe)
    |> assign(:changeset, Recipes.change_recipe(recipe))
    |> assign(:selected_hero, selected_hero)
    |> assign(:__add_n_ingredients, 1)
    |> assign(:__add_n_steps, 1)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Recipe")
    # we have to prefill the steps with the embedded schema
    |> assign(:recipe, build_base_recipe())
    |> assign(:changeset, build_base_recipe() |> Recipes.change_recipe())
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Recipes.get_recipe!(id)
    {:ok, _} = Recipes.delete_recipe(recipe)

    {:noreply,
     socket
     |> put_flash(:info, "Recipe deleted!")
     |> push_redirect(to: Routes.recipe_index_path(socket, :index))}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    sA = socket.assigns

    changeset =
      sA.recipe
      |> Recipes.change_recipe(recipe_params)
      |> Map.put(:action, :validate)

    {hero_image, _} = Map.get(recipe_params, "hero_image", "0") |> Integer.parse()

    socket =
      socket
      |> handle_change_num_ingr_or_steps(recipe_params)
      |> assign(:selected_hero, hero_image)
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    save_recipe(socket, socket.assigns.live_action, recipe_params)
  end

  def handle_event("add-instruction", _val, socket) do
    sA = socket.assigns
    existing_steps = Map.get(sA.changeset.changes, :steps, sA.recipe.steps)

    steps_to_add = get_int_or_convert_string(sA.__add_n_steps)

    new_steps =
      for _ <- 1..steps_to_add,
          do: Recipes.change_step(%Recipe.Step{temp_id: GalleyUtils.get_temp_id()})

    steps = existing_steps |> Enum.concat(new_steps)
    steps = if Enum.count(steps) >= 30, do: Enum.take(steps, 30), else: steps

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:steps, steps)
    {:noreply, assign(socket, changeset: changeset, num_steps: Enum.count(steps))}
  end

  def handle_event("add-ingredient", _val, socket) do
    sA = socket.assigns
    existing_ingredients = Map.get(sA.changeset.changes, :ingredients, sA.recipe.ingredients)
    ingr_to_add = get_int_or_convert_string(sA.__add_n_ingredients)

    new_ingr =
      for _ <- 1..ingr_to_add,
          do: Recipes.change_ingredient(%Recipe.Ingredient{temp_id: GalleyUtils.get_temp_id()})

    ingredients = existing_ingredients |> Enum.concat(new_ingr)

    ingredients =
      if Enum.count(ingredients) >= 30, do: Enum.take(ingredients, 30), else: ingredients

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:ingredients, ingredients)
    {:noreply, assign(socket, changeset: changeset, num_ingredients: Enum.count(ingredients))}
  end

  def handle_event("remove-ingredient", params, socket) do
    id_to_remove = params["remove"]

    if Map.has_key?(socket.assigns.changeset.changes, :ingredients) do
      ingredients =
        socket.assigns.changeset.changes.ingredients
        |> Enum.reject(fn changeset ->
          ingredient = changeset.data
          ingredient.temp_id == id_to_remove && changeset.action == :insert
        end)

      changeset = socket.assigns.changeset |> Ecto.Changeset.put_embed(:ingredients, ingredients)

      {:noreply,
       assign(socket,
         changeset: changeset,
         num_ingredients: length(ingredients)
       )}
    else
      {:noreply, socket}
    end
  end

  # how to remove existing single item in a DB and reload the stuff
  # https://discord.com/channels/269508806759809042/269509152387104771/968996144623534130
  #
  # very similar to "remove-ingredient"
  # don't think we can refactor because we can't dynamically access changeset.steps
  def handle_event("remove-step", params, socket) do
    id_to_remove = params["remove"]

    if Map.has_key?(socket.assigns.changeset.changes, :steps) do
      steps =
        socket.assigns.changeset.changes.steps
        |> Enum.reject(fn changeset ->
          step = changeset.data
          # only allow deleting of items that have been inserted.
          step.temp_id == id_to_remove && changeset.action == :insert
        end)

      changeset = socket.assigns.changeset |> Ecto.Changeset.put_embed(:steps, steps)
      {:noreply, assign(socket, changeset: changeset, num_steps: length(steps))}
    else
      {:noreply, socket}
    end
  end

  # A bit hacky but:
  # Delete the recipe steps  and refetch the recipe
  # Loop over the old changeset's `changes` field, and keep the previous changes (save for the deleted one)
  # Reassign the data from the db to the socket changeset, and put the changeset changes back in.
  def handle_event("remove-persisted-step", %{"remove" => step_id_to_remove}, socket) do
    Recipes.delete_recipe_step(socket.assigns.changeset.data, step_id_to_remove)
    updatedRecipe = Recipes.get_recipe!(socket.assigns.changeset.data.id)
    old_changes = socket.assigns.changeset.changes
    # we need to bake the changeset and recreate it in order to avoid
    # conflicts with unsaved changes with dynamically added form fields
    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_embed(:steps, updatedRecipe.steps)
      |> Ecto.Changeset.apply_changes()
      |> Recipes.change_recipe()
      # HACK: for now, we have to reference previous changeset changes via old_changes inside update
      |> Map.update(:changes, %{}, fn changes ->
        steps = Map.get(socket.assigns.changeset.changes, :steps, [])

        if length(steps) > 0 do
          existing_changed_steps =
            Enum.filter(steps, fn change ->
              change.action == :insert || change.data.id != step_id_to_remove
            end)

          %{old_changes | steps: existing_changed_steps}
        else
          changes
        end
      end)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:recipe, updatedRecipe)}
  end

  def handle_event("remove-persisted-ingredient", %{"remove" => ingr_id}, socket) do
    Recipes.delete_ingredient_step(socket.assigns.changeset.data, ingr_id)
    updatedRecipe = Recipes.get_recipe!(socket.assigns.changeset.data.id)
    old_changeset = socket.assigns.changeset.changes

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_embed(:ingredients, updatedRecipe.ingredients)
      |> Ecto.Changeset.apply_changes()
      |> Recipes.change_recipe()
      # HACK: referencing old variables inside of update.
      |> Map.update(:changes, %{}, fn changes ->
        ingredients = Map.get(old_changeset, :ingredients, [])

        if length(ingredients) > 0 do
          %{
            old_changeset
            | ingredients:
                Enum.filter(old_changeset.ingredients, fn change ->
                  change.action == :insert || change.data.id != ingr_id
                end)
          }
        else
          changes
        end
      end)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:recipe, updatedRecipe)}
  end

  def handle_event("remove-persisted-upload", %{"remove" => photo_id}, socket) do
    Recipes.delete_ingredient_photo(socket.assigns.changeset.data, photo_id)
    updatedRecipe = Recipes.get_recipe!(socket.assigns.changeset.data.id)

    {:noreply,
     socket
     |> assign(:changeset, Recipes.change_recipe(updatedRecipe))
     |> assign(:recipe, updatedRecipe)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :recipe_img, ref)}
  end

  defp save_recipe(socket, :edit, recipe_params) do
    recipe_params = handle_upload(socket, socket.assigns.live_action, recipe_params)

    case Recipes.update_recipe(socket.assigns.recipe, recipe_params) do
      {:ok, recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe updated successfully!")
         |> push_redirect(to: Routes.recipe_show_path(socket, :show, recipe, recipe.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update recipe.")
         |> assign(:changeset, changeset)}
    end
  end

  defp save_recipe(socket, :new, recipe_params) do
    recipe_params = handle_upload(socket, socket.assigns.live_action, recipe_params)

    case Recipes.insert_recipe(recipe_params, socket.assigns.current_user) do
      {:ok, recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe created successfully")
         |> push_redirect(to: Routes.recipe_show_path(socket, :show, recipe, recipe.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def tag_input(form, field, opts \\ []) do
    incoming_val = Phoenix.HTML.Form.input_value(form, field)

    tags =
      if is_binary(incoming_val) do
        incoming_val
      else
        incoming_val
        |> Enum.map(fn t -> t.name end)
        |> Enum.join(", ")
      end

    # render text using the text_input after converting tags to text
    kwrds = Keyword.merge([value: tags], opts)
    Phoenix.HTML.Form.text_input(form, field, kwrds)
  end

  ## - Components --

  @doc """
  Render a button and a number input together.
  Used for adding N ingredients / instructions to a recipe.
  """
  def render_combo_btn(assigns) do
    ~H"""
    <button class="btn-white mt-8 rounded-r-none -mr-4 pr-8" type="button" phx-click={assigns.click}>
      Add
    </button>
    <%= number_input(assigns.form_state, assigns.atom,
      value: assigns.num_entity,
      max: 20,
      min: 1,
      class: "w-20 -ml-2 pr-4 outline-none rounded-none"
    ) %>
    <button class="btn-white mt-8 -ml-4 rounded-l-none" type="button" phx-click={assigns.click}>
      <%= assigns.what_to_add %>
    </button>
    """
  end

  ## -- File Upload Stuff

  def uploadType(upload) do
    case upload do
      %Galley.Recipes.Recipe.Image{} -> :existing_upload
      %Phoenix.LiveView.UploadEntry{} -> :new_upload
      _ -> :unknown
    end
  end

  @doc """
  gives us a returned list of items TO Be uploaded and already uploaded (in edit mode)
  """
  def get_uploads(uploads, recipe) do
    uploads.recipe_img.entries ++ recipe.uploaded_images
  end

  defp get_current_hero_idx(uploads, recipe) do
    up = get_uploads(uploads, recipe)

    if length(up) > 0 do
      {_up, idx} =
        get_uploads(uploads, recipe)
        |> Enum.with_index()
        |> Enum.filter(fn {up, _idx} -> up.is_hero end)
        |> List.first()

      idx
    else
      0
    end
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  # take the form_params and extract the uploaded entries
  # then put the uploaded files into the form params to be inserted into the db.
  defp handle_upload(socket, :new, form_params) do
    imgs =
      consume_uploads(socket)
      |> attach_selected_hero_to_uploads(form_params)

    Map.put(form_params, "uploaded_images", imgs)
  end

  defp handle_upload(socket, :edit, form_params) do
    existing_uploads = socket.assigns.recipe.uploaded_images
    uploaded_images = consume_uploads(socket)
    # FIXME: I wonder if this should be existing_uploads at the end?
    uploads =
      (existing_uploads ++ uploaded_images)
      |> attach_selected_hero_to_uploads(form_params)

    Map.put(form_params, "uploaded_images", uploads)
  end

  # NOTE: In this function we get the uploads out of the socket and put them in
  # a temporary place and then return the expected map of data for the files so
  # that live view can continue on it's way. We handle compression, uploading to
  # s3, and changing the map of data (url, url_thumb, is_local, etc) later
  # (see compress_and_upload_s3 in recipes.ex)
  defp consume_uploads(socket) do
    consume_uploaded_entries(socket, :recipe_img, fn %{path: path}, entry ->
      uploads_dir = Galley.Application.get_uploads_folder()
      client_name = entry.client_name |> String.replace(" ", "_")
      prefix = Path.basename(path) |> String.replace("live_view_upload-", "")

      full_file = Path.join([uploads_dir, "#{prefix}_#{client_name}"])
      File.rename!(path, full_file)

      {:ok,
       %{
         "url" => Routes.static_path(socket, "/uploads/#{Path.basename(full_file)}"),
         "url_thumb" => Routes.static_path(socket, "/uploads/#{Path.basename(full_file)}"),
         "key_s3" => "",
         "local_path" => full_file,
         "is_local" => true
       }}
    end)
  end

  # iterates over images and attaches the selected integer of the image to be the hero
  # and sets is_hero on that image.
  defp attach_selected_hero_to_uploads(uploaded_images, form_params) do
    uploaded_images
    |> Enum.with_index()
    |> Enum.map(fn {image_data, i} ->
      {parsed_int, _} = Integer.parse(Map.get(form_params, "hero_image", "0"))
      # FIXME: this only half works because what the user clicks on the front end doesn't
      # always correspond to the order of the list that the images are in.
      is_hero = if i == parsed_int, do: true, else: false

      case image_data do
        # the image is already in the DB, and thus has schema
        %Galley.Recipes.Recipe.Image{} ->
          Map.from_struct(%{image_data | is_hero: is_hero})

        # the image has just been uploaded and is t hus just a bunch of data
        image_data when is_map(image_data) ->
          Map.put(image_data, "is_hero", is_hero)
      end
    end)
  end

  defp has_temp_id(temp_id) do
    if is_binary(temp_id) do
      if String.length(temp_id) > 0 do
        true
      else
        false
      end
    else
      !is_nil(temp_id)
    end
  end

  defp handle_change_num_ingr_or_steps(socket, %{
         "__add_n_ingredients" => ingr_count,
         "__add_n_steps" => step_count
       }) do
    socket
    |> assign(:__add_n_ingredients, ingr_count)
    |> assign(:__add_n_steps, step_count)
  end

  defp get_int_or_convert_string(int_or_string) when is_binary(int_or_string) do
    String.to_integer(int_or_string)
  end

  defp get_int_or_convert_string(int_or_string) when is_integer(int_or_string) do
    int_or_string
  end
end
