defmodule GalleyWeb.AdminSettingsDownloadController do
  use GalleyWeb, :controller

  alias Galley.Accounts

  def download_db(conn, _params) do
    if Accounts.is_admin?(conn.assigns.current_user) do
      db_path =  Application.fetch_env!(:galley, Galley.Repo)[:database]
      conn
      |> send_download({:file,  db_path})
    else
      conn
      |> redirect(to: "/")
    end
  end
end
