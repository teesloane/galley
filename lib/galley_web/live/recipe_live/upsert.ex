defmodule GalleyWeb.RecipeLive.Upsert do
  use GalleyWeb, :live_view

  alias Galley.Recipes
  alias Galley.Recipes.Recipe, as: Recipe

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:formState, 0)
     |> assign(:uploaded_images, [])
     |> allow_upload(:recipe_img, accept: ~w(.jpg .jpeg .png), max_entries: 4)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # This is how we set the form to work for either :edit or :new
  defp apply_action(socket, :edit, %{"id" => id}) do
    recipe = Recipes.get_recipe!(id)
    socket
    |> assign(:page_title, "Edit - #{recipe.title}")
    |> assign(:recipe, recipe)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Recipe")
    # we have to prefill the steps with the embedded schema
    |> assign(:recipe, %Recipe{
      ingredients: [
        %Recipe.Ingredient{
          temp_id: GalleyUtils.get_temp_id(),
          quantity: "",
          measurement: "",
          ingredient: ""
        },
      ],
      steps: [
        %Recipe.Step{temp_id: GalleyUtils.get_temp_id(), timer: nil, instruction: nil}
      ],
      tags: []
    })
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
end
