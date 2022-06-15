defmodule GalleyWeb.AdminLive.Users do
  use GalleyWeb, :live_view
  alias Galley.Accounts
  alias Galley.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    state = %{
      users: Accounts.list_users(),
      changeset: Accounts.change_user_registration(%User{})
    }

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(_arams, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"user" => user}, socket) do
    case Accounts.register_user(user) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(socket, :edit, &1)
          )

        {:noreply,
         socket
         |> put_flash(:info, "User registration done.")
         |> assign(:users, Accounts.list_users()),
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:changeset, changeset)}
    end
  end
end
