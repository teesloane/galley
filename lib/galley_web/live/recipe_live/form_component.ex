defmodule GalleyWeb.RecipeLive.FormComponent do
  use GalleyWeb, :live_component

  alias Galley.Recipes
  alias Galley.Recipes.RecipeStep

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
    existing_steps =
      Map.get(
        socket.assigns.changeset.changes,
        :steps,
        socket.assigns.recipe.steps
      )

    steps = existing_steps |> Enum.concat([
      Recipes.change_step(%RecipeStep{id: GalleyUtils.get_temp_id()})
    ])
    changeset = socket.assigns.changeset |> Ecto.Changeset.put_embed(:steps, steps)
    {:noreply, assign(socket, changeset: changeset)}
  end

  defp save_recipe(socket, :edit, recipe_params) do
    case Recipes.update_recipe(socket.assigns.recipe, recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe updated successfully!")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_recipe(socket, :new, recipe_params) do
    IO.inspect(recipe_params)
    case Recipes.create_recipe(recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset)
        {:noreply, assign(socket, changeset: changeset)}
    end
  end


end
