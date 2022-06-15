defmodule GalleyWeb.AdminLive.Recipes do
  use GalleyWeb, :live_view


  @impl true
  def mount(_params, _session, socket) do
    state = %{}
    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(_arams, _url, socket) do
    {:noreply, socket}
  end
end
