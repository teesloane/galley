defmodule GalleyWeb.RecipeLive.Index do
  use GalleyWeb, :live_view

  alias Galley.Recipes

  @recipe_filters ["All", "My Recipes", "Under an hour", "Under 30 minutes"]

  @impl true
  def mount(_params, _session, socket) do
    state = %{
      recipes: list_recipes(),
      search_query: "",
      search_filter: "All",
      search_tags: "",
      page_heading: "Recipes"
    }

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def get_recipe_filters() do
    @recipe_filters
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    user_id = socket.assigns.current_user.id
    recipes = Recipes.search_recipes(search, user_id)

    tagged =
      if search["tags"] !== "" do
        x = search["tags"] |> String.split(",") |> Enum.join("  ")

        "tagged with: #{x}"
      end

    page_heading = fn ->
      l = recipes |> length

      case search["filter"] do
        "My Recipes" -> "Your recipes (#{l}) #{tagged}"
        "Under an hour" -> "Recipes under an hour (#{l})"
        "Under 30 minutes" -> "Recipes under 30 minutes (#{l})"
        _ -> "Recipes"
      end
    end

    socket =
      socket
      |> assign(:recipes, recipes)
      |> assign(:search_filter, search["filter"])
      |> assign(:search_query, search["query"])
      |> assign(:search_tags, search["tags"])
      |> assign(:page_heading, page_heading.())

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Galley - Recipes")
    |> assign(:recipe, nil)
  end

  defp list_recipes do
    Recipes.list_recipes()
  end
end
