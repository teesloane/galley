defmodule GalleyWeb.LiveComponent.Typeahead do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form, only: [text_input: 3]

  @moduledoc """
  The typeahead component is concerned with receiving a list a
  list and a query and providing thse list options to the user as they type
  """

  @impl true
  def mount(socket) do
    state = %{
      taggings: [],
      query: ""
    }

    {:ok, assign(socket, state)}
  end

  # def update(assigns, socket) do
  #   {:ok, socket}
  # end

  @impl true
  def handle_event("do-thing", _unsigned_params, socket) do
    IO.inspect("event")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
    <%= text_input(@form_name, @form_key,
      placeholder: @placeholder,
      "phx-debounce": "200",
      class: "w-full",
      value: @value) %>

    <%= if Enum.any?(@tags) do %>
      <ul class="absolute bg-white border-2 w-full z-10 p-2 ">
        <%= for tag <- @tags do %>
          <li class="divide-y divide-neutral-500"><%= tag %></li>
        <% end %>
      </ul>
      <% end %>
      </div>
    """
  end
end
