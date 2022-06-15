defmodule GalleyWeb.AdminLive.TopBar do
  use Phoenix.Component
  use GalleyWeb, :live_view

  def topbar(assigns) do
    index_links = [
      %{name: "Users", link: Routes.admin_users_path(assigns.socket, :show)},
      %{name: "Recipes", link: Routes.admin_recipes_path(assigns.socket, :show)}
    ]

    ~H"""
    <div class="flex flex-row bg-blue-600 text-white pl-4 text-sm">
        <%= for l <- index_links do %>
            <%= link(l.name, to: l.link, class: "py-2 pr-4")%>
        <% end %>
    </div>
    """
  end

end
