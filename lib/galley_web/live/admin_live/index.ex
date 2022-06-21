defmodule GalleyWeb.AdminLive.Index do
  use GalleyWeb, :live_view

  def index_links(socket) do
    [
      %{name: "Users", link: Routes.admin_users_path(socket, :show)},
      %{name: "Recipes", link: Routes.admin_recipes_path(socket, :show)}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    state = %{}

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(_arams, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("migrate_aris", _value, socket) do
    has_migrated = Galley.Recipes.get_recipe_by_slug("black-bean-salad")

    if has_migrated === nil do
      Galley.Recipes.MigrateAris.do_migration(15000)

      {:noreply,
       socket
       |> put_flash(:info, "Finished migration")}
    else
      {:noreply,
       socket
       |> put_flash(:info, "Migration already completed")}
    end
  end
end
