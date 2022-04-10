defmodule GalleyWeb.RecipeLive.Upsert do
  use GalleyWeb, :live_view

  alias Galley.Recipes
  alias Galley.Recipes.Recipe
  alias Galley.Recipes.RecipeStep

  @impl true
  def mount(_params, _session, socket) do
    state = %{
      formState: 0
    }

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # This is how we set the form to work for either :edit or :new
  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Recipe")
    |> assign(:recipe, Recipes.get_recipe!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Recipe")
    # we have to prefill the steps with the embedded schema
    |> assign(:recipe, %Recipe{
      steps: [
        %RecipeStep{id: 1, timer: "fo", instruction: "jo"},
        %RecipeStep{id: 2, timer: "fo", instruction: "joooo"}
      ]
    })
  end

  @impl true
  def handle_event("form_move_forward", _val, socket) do
    {:noreply, update(socket, :formState, fn fS -> fS + 1 end)}
  end

  def handle_event("form_move_backward", _val, socket) do
    {:noreply, update(socket, :formState, fn fS -> fS - 1 end)}
  end

  # def handle_event("add-instruction", val, socket) do
  #   IO.inspect(socket, pretty: true)
  #   # new_recipe = Kernel.put_in(socket, [:Recipe, :steps], %RecipeStep{timer: "", instruction: ""})
  #   # assign(socket, :recipe, new_recipe)
  #   {:noreply, socket}

  # end

  # def handle_event("add-instruction", val, socket) do
  #   IO.inspect(val, pretty: true)
  #   # new_recipe = Kernel.put_in(socket, [:Recipe, :steps], %RecipeStep{timer: "", instruction: ""})
  #   # assign(socket, :recipe, new_recipe)
  #   {:noreply, socket}

  # end
end
