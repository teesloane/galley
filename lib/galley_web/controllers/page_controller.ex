defmodule GalleyWeb.PageController do
  use GalleyWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
