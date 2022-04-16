defmodule GalleyWeb.RecipeLive.Index do
  use GalleyWeb, :live_view

  alias Galley.Recipes
  alias Galley.Recipes.Recipe

  @impl true
  def mount(_params, _session, socket) do
    state = %{
      recipes: list_recipes(),
      search_phrase: "",
      formState: 0
    }

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    recipes = list_recipes()

    filtered_recipes =
      Enum.filter(recipes, fn r ->
        r.title
        |> String.downcase()
        |> String.contains?(String.downcase(query))
      end)

    recipes = if String.length(query) == 0, do: recipes, else: filtered_recipes
    {:noreply, assign(socket, :recipes, recipes)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Recipes")
    |> assign(:recipe, nil)
  end

  defp list_recipes do
    Recipes.list_recipes()
  end

  # defp search_filter(items, search) do
  #   Enum.filter(items, fn i ->
  #     i.name
  #     |> String.downcase()
  #     |> String.contains?(String.downcase(search))
  #   end)
  # end
end
