defmodule GalleyWeb.RecipeLive.FormComponent do
  use GalleyWeb, :live_component

  alias Galley.Recipes
  alias Galley.Recipes.RecipeStep
  alias Galley.Recipes.RecipeIngredient

  @impl true
  def update(%{recipe: recipe} = assigns, socket) do
    changeset = Recipes.change_recipe(recipe)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
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
        Recipes.change_step(%RecipeStep{id: GalleyUtils.get_temp_id()})
      ])

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:steps, steps)
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add-ingredient", _val, socket) do
    sA = socket.assigns
    existing_ingredients = Map.get(sA.changeset.changes, :ingredients, sA.recipe.ingredients)

    ingredients =
      existing_ingredients
      |> Enum.concat([
        Recipes.change_ingredient(%RecipeIngredient{id: GalleyUtils.get_temp_id()})
      ])

    changeset = sA.changeset |> Ecto.Changeset.put_embed(:ingredients, ingredients)
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove-ingredient", %{"remove" => id_to_remove}, socket) do
    IO.inspect(socket, pretty: true)

    ingredients =
      socket.assigns.changeset.changes.ingredients
      |> Enum.reject(fn %{:data => ingredient} ->
        ingredient.id == id_to_remove
      end)

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_embed(:ingredients, ingredients)
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :recipe_img, ref)}
  end

  defp save_recipe(socket, :edit, recipe_params) do
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
    case Recipes.create_recipe(socket.assigns.current_user, recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  ## -- File Upload Stuff

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

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
