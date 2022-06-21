defmodule GalleyWeb.RecipeLive.Show do
  use GalleyWeb, :live_view

  alias Galley.Recipes

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id, "slug" => slug}, _, socket) do
    recipe = Recipes.get_recipe_by_id_and_slug!(id, slug)

    {:noreply,
     socket
     |> assign(:page_title, "Galley - #{recipe.title}")
     |> assign(:recipe, recipe)}
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
end
