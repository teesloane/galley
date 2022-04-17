defmodule GalleyWeb.LayoutView do
  use GalleyWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def sidebar_links(conn) do
    [
      %{name: "Browse Recipes", link: Routes.recipe_index_path(conn, :index)},
      %{name: "+ Add a Recipe", link: Routes.recipe_upsert_path(conn, :new)}
      # %{name: "Meal Planning", link: ""},
      # %{name: "The Pantry", link: ""},
      # %{name: "Support Galley", link: ""}
    ]
  end
end
