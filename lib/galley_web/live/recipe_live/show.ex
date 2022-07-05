defmodule GalleyWeb.RecipeLive.Show do
  use GalleyWeb, :live_view

  alias Galley.Recipes

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{is_favourite: false})}
  end

  @impl true
  def handle_params(%{"id" => id, "slug" => slug}, _, socket) do
    recipe = Recipes.get_recipe_by_id_and_slug!(id, slug)

    {:noreply,
     socket
     |> assign(:page_title, "Galley - #{recipe.title}")
     |> assign(:recipe, recipe)
     |> assign(:is_favourite, Recipes.is_favourite?(get_favourite_attrs(socket, recipe)))}
  end

  @impl true
  def handle_event("favourite-recipe", _params, socket) do
    res = Recipes.favourite_recipe(get_favourite_attrs(socket))

    case res do
      {:ok, fav} ->
        {:noreply, socket |> assign(:is_favourite, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unfavourite-recipe", _params, socket) do
    res = Recipes.unfavourite_recipe(get_favourite_attrs(socket))

    case res do
      {:ok, fav} ->
        {:noreply, socket |> assign(:is_favourite, false)}

      _ ->
        {:noreply, socket}
    end
  end

  def get_hero_img(recipe_images) do
    [default | _other] = recipe_images
    Enum.find(recipe_images, default, fn x -> x.is_hero == true end)
  end

  def get_other_images(recipe_images) do
    filtered = Enum.filter(recipe_images, fn x -> x.is_hero == false end)

    if length(filtered) == length(recipe_images) do
      # if no images are marked with is_hero: true...
      [_hero | non_hero] = recipe_images
      non_hero
    else
      filtered
    end
  end

  defp get_favourite_attrs(socket) do
    user = get_user_from_socket(socket)

    %{
      user_id: user.id,
      recipe_id: socket.assigns.recipe.id
    }
  end

  defp get_favourite_attrs(socket, recipe) do
    user = get_user_from_socket(socket)

    %{
      user_id: user.id,
      recipe_id: recipe.id
    }
  end
end
