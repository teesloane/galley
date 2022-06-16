defmodule GalleyWeb.AdminLive.Recipes do
  use GalleyWeb, :live_view


  @impl true
  def mount(_params, _session, socket) do
    state = %{
      recipes: Galley.Recipes.list_recipes(),
    }
    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:recipe, Galley.Recipes.get_recipe!(id))
  end

  defp apply_action(socket, :show, params) do
    socket
    |> assign(:recipes, Galley.Recipes.list_recipes())
  end
end
