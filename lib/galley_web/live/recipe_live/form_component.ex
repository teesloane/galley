defmodule GalleyWeb.RecipeLive.FormComponent do
  use GalleyWeb, :live_component

  alias Galley.Recipes
  alias Galley.Recipes.Recipe

  @impl true
  def update(%{recipe: recipe} = assigns, socket) do
    changeset = Recipes.change_recipe(recipe)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:num_ingredients, 1)
     |> assign(:num_steps, 1)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do

    changeset =
      socket.assigns.recipe
      |> Recipes.change_recipe(recipe_params)
      |> Map.put(:action, :validate)
    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    save_recipe(socket, socket.assigns.action, recipe_params)
  end

  def handle_event("add-instruction", _val, socket) do
    sA = socket.assigns
    existing_steps = Map.get(sA.changeset.changes, :steps, sA.recipe.steps)

    steps =
      existing_steps
      |> Enum.concat([
        Recipes.change_step(%Recipe.Step{temp_id: GalleyUtils.get_temp_id()})
      ])

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:steps, steps)
    {:noreply, assign(socket, changeset: changeset, num_steps: length(steps))}
  end

  def handle_event("add-ingredient", _val, socket) do
    sA = socket.assigns
    existing_ingredients = Map.get(sA.changeset.changes, :ingredients, sA.recipe.ingredients)

    ingredients =
      existing_ingredients
      |> Enum.concat([
        Recipes.change_ingredient(%Recipe.Ingredient{temp_id: GalleyUtils.get_temp_id()})
      ])

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:ingredients, ingredients)
    {:noreply, assign(socket, changeset: changeset, num_ingredients: length(ingredients))}
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
      {:noreply, assign(socket,
          changeset: changeset,
          num_ingredients: length(ingredients))}
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
              existing_changed_steps = Enum.filter(steps, fn change ->
                  change.action == :insert || change.data.id != step_id_to_remove
              end)
              %{old_changes | steps: existing_changed_steps}
            else
              changes
            end
        end)

    {:noreply, socket
     |> assign(:changeset, changeset)
     |> assign(:recipe, updatedRecipe)
    }
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
              %{old_changeset | ingredients: Enum.filter(old_changeset.ingredients, fn change ->
                   change.action == :insert || change.data.id != ingr_id
                 end)}
            else
              changes
            end
        end)

    {:noreply, socket
     |> assign(:changeset, changeset)
     |> assign(:recipe, updatedRecipe)
    }
  end

  def handle_event("remove-persisted-upload", %{"remove" => photo_id}, socket) do
    Recipes.delete_ingredient_photo(socket.assigns.changeset.data, photo_id)
    updatedRecipe = Recipes.get_recipe!(socket.assigns.changeset.data.id)
    IO.inspect(photo_id)
    changeset =
      socket.assigns.changeset
        |> Ecto.Changeset.put_embed(:uploaded_images, updatedRecipe.uploaded_photos)

    {:noreply, socket
     |> assign(:changeset, changeset)
     |> assign(:recipe, updatedRecipe)
    }
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :recipe_img, ref)}
  end

  defp save_recipe(socket, :edit, recipe_params) do
    recipe_params = handle_upload(socket, socket.assigns.action, recipe_params)
    case Recipes.update_recipe(socket.assigns.recipe, recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe updated successfully!")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update recipe.")
         |> assign(:changeset, changeset)}
    end
  end

  defp save_recipe(socket, :new, recipe_params) do
    recipe_params = handle_upload(socket, socket.assigns.action, recipe_params)
    case Recipes.insert_recipe(socket.assigns.current_user, recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def tag_input(form, field, opts \\ []) do
    incoming_val = Phoenix.HTML.Form.input_value(form, field)
    tags =  if is_binary(incoming_val) do
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

  def render_file_upload(assigns) do
    ~H"""
      <section phx-drop-target={@uploads.recipe_img.ref} class="">
        <div class="">
          <div class="sm:h-48 sm:w-48 flex flex-col justify-center rounded-sm bg-gray-50 border border-neutral-200">
            <div class="m-4">
              <div class="flex items-center justify-center w-full">
                <label class="flex flex-col w-full  justify-center  border-4 border-blue-200 border-dashed hover:bg-gray-100 hover:border-gray-300">
                  <div class="flex flex-col items-center justify-center pt-7">
                    <!-- upload icon -->
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8 text-gray-400 group-hover:text-gray-600"
                        fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    <p class="pt-1 text-sm tracking-wider text-gray-400 group-hover:text-gray-600">
                      Attach a file</p>
                  </div>
                  <%= live_file_input @uploads.recipe_img, class: "opacity-0"%>
                </label>
              </div>
            </div>
          </div>
        </div>
      </section>
    """
  end

  @doc """
  Renders icon of an image to be uploades, as well as the
  ability to click on it and make it a "hero" image
  """
  def render_to_be_uploaded(assigns) do
    ~H"""
    <article class="upload-entry w-full sm:w-48 sm:h-48 relative mb-4">

      <%= label do %>
        <%= live_img_preview(@entry, class: "w-full sm:w-48 sm:h-48 rounded-sm object-cover") %>
        <%= radio_button @f, :hero_image, @entry.ref, class: "peer sr-only", value: @entry.ref  %>
        <div class="absolute top-0 left-0 w-full sm:w-48 sm:h-48 border-4 border-neutral-300 rounded-sm peer-checked:border-blue-500"/>
      <% end %>

      <button
        class="absolute top-0 right-0 bg-black text-white py-1 px-3"
        phx-click="cancel-upload"
        type="button"
        style="margin: 4px"
        phx-value-ref={@entry.ref}
        aria-label="cancel"
        phx-target={@myself}
      >
        &times;
      </button>

      <%= for err <- upload_errors(@uploads.recipe_img, @entry) do %>
        <p class="alert alert-danger"><%= error_to_string(err) %></p>
      <% end %>
    </article>
    """
  end

  @doc """
  Render already uploaded images from the database.
  """
  def render_already_uploaded(assigns) do
    ~H"""
    <article class="upload-entry w-full sm:w-48 sm:h-48 relative mb-4">

      <%= label do %>
        <img src={@entry.url} class="w-full sm:w-48 sm:h-48 rounded-sm object-cover" />
        <%= radio_button @f, :hero_image, @ref, class: "peer sr-only", value: @ref  %>
        <div class="absolute top-0 left-0 w-full sm:w-48 sm:h-48 border-4 border-neutral-300 rounded-sm peer-checked:border-blue-500"/>
      <% end %>

      <button
        class="absolute top-0 right-0 bg-black text-white py-1 px-3"
        phx-click="remove-persisted-upload"
        phx-value-remove={@entry.id}
        type="button"
        style="margin: 4px"
        phx-target={@myself}
      >
        &times;
      </button>

    </article>
    """

  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  # take the form_params and extract the uploaded entries
  # then put them uploaded files into the form params to be inserted into the db.
  # FIXME: this should be set to be dev only as it uploads to local host,
  # maybe we can match on a get_env call.
  defp handle_upload(socket, :new, form_params) do
    uploaded_images = consume_uploads(socket, form_params)
    Map.put(form_params, "uploaded_images", uploaded_images)
  end

  defp handle_upload(socket, :edit, form_params) do
    existing_uploads  = socket.assigns.recipe.uploaded_images
    uploaded_images = consume_uploads(socket, form_params)
    uploads =
      (existing_uploads ++ uploaded_images)
      |> attach_selected_hero_to_uploads(form_params)
    Map.put(form_params, "uploaded_images", uploads)
  end

  # takes uploaded images and transforms them to be db friendly.
  defp consume_uploads(socket, form_params) do
    uploaded_images = consume_uploaded_entries(socket, :recipe_img, fn %{path: path}, _entry ->
      upload_folder = Path.join([:code.priv_dir(:galley), "static", "uploads"])
      # make the upload directory if it doesn't exist
      File.mkdir_p!(upload_folder)
      dest = Path.join([upload_folder, Path.basename(path)])
      # The `static/uploads` directory must exist for `File.cp!/2` to work.
      File.cp!(path, dest)
      {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")}
    end)

    attach_selected_hero_to_uploads(uploaded_images, form_params)
  end


  # iterates over images and attaches the selected integer of the image to be the hero
  # and sets is_hero on that image.
  defp attach_selected_hero_to_uploads(uploaded_images, form_params) do
    uploaded_images
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        {parsed_int, _} = Integer.parse(Map.get(form_params, "hero_image", "0"))
        is_hero = if i == parsed_int, do: true, else: false
        # we have to handle for existing struct images and new maps
        # when setting the images that will be the hero.
        case v do
          %Galley.Recipes.Recipe.Image{} ->
            Map.from_struct(%{v | is_hero: is_hero})
          v when  is_binary(v) ->
            %{"url" => v, "is_hero" => is_hero}
          v when is_map(v) ->
            Map.put(v, "is_hero", is_hero)
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

end
