defmodule GalleyWeb.AdminLive.Users do
  use GalleyWeb, :live_view
  alias Galley.Accounts
  alias Galley.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    state = %{
      users: Accounts.list_users(),
      changeset: Accounts.change_user_registration(%User{}),
      modal_open: false
    }

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:users, Accounts.list_users())
  end

  @impl true
  def handle_event("promote_user", _value, socket) do
    user = socket.assigns.user
    Accounts.promote_user_to_admin(user)

    {:noreply,
     socket
     |> assign(:user, Accounts.get_user!(user.id))
     |> put_flash(:info, "Promoted #{user.username}")}
  end

  def handle_event("demote_user", _value, socket) do
    user = socket.assigns.user
    Accounts.demote_admin_to_contributor(user)

    {:noreply,
     socket
     |> assign(:user, Accounts.get_user!(user.id))
     |> put_flash(:info, "Demoted #{user.username} from admin")}
  end

  def handle_event("ban_user", _value, socket) do
    user = socket.assigns.user
    Accounts.ban_user(user)

    {:noreply,
     socket
     |> assign(:user, Accounts.get_user!(user.id))
     |> put_flash(:info, "Banned #{user.username}")}
  end

  def handle_event("unban_user", _value, socket) do
    user = socket.assigns.user
    Accounts.unban_user(user)

    {:noreply,
     socket
     |> assign(:user, Accounts.get_user!(user.id))
     |> put_flash(:info, "Banned #{user.username}")}
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
         |> assign(:users, Accounts.list_users())}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:changeset, changeset)}
    end
  end
end
