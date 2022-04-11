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

    steps = existing_steps |> Enum.concat([%RecipeStep{id: get_temp_id()}])
    changeset = socket.assigns.changeset |> Ecto.Changeset.put_embed(:steps, steps)
    {:noreply, assign(socket, changeset: changeset)}
  end

  defp get_temp_id, do: :crypto.strong_rand_bytes(5) |> Base.url_encode64() |> binary_part(0, 5)

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
    recipe_params = Map.update!(recipe_params, "total_time", &(fmt_total_time(&1)))
    case Recipes.create_recipe(recipe_params) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # gets the total_time val in a recipe and returns it as a string:
  # ex: hour: 03, minutes: 09 -> 3:09
  # TODO: move this into util and pass the params in
  defp fmt_total_time(total_time) do
    hour = total_time["hour"]
    min = total_time["minute"]
    IO.puts(String.length min)
    if String.length(min) == 1 do
      "#{hour}:0#{min}"
    else
      "#{hour}:#{min}"
    end
  end

end
