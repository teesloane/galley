defmodule GalleyWeb.LayoutView do
  use GalleyWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def topbar_links(conn, current_user) do
    is_logged_in = current_user !== nil
    is_logged_out = current_user === nil
    is_admin = Galley.Accounts.is_admin?(current_user)

    [
      %{
        name: "Admin",
        link: Routes.admin_index_path(conn, :index),
        condition: is_admin
      },
      %{
        name: "Browse Recipes",
        link: Routes.recipe_index_path(conn, :index),
        condition: is_logged_in
      },
      %{
        name: "+ Add a Recipe",
        link: Routes.recipe_upsert_path(conn, :new),
        condition: is_logged_in
      },

      %{
        name: "Settings",
        link: Routes.user_settings_path(conn, :edit),
        condition: is_logged_in
      },
      %{
        name: "Log in",
        link: Routes.user_session_path(conn, :new),
        condition: is_logged_out
      },
      %{
        name: "Log out",
        condition: is_logged_in,
        link: Routes.user_session_path(conn, :delete),
        method: :delete
      }
    ]
  end
end
