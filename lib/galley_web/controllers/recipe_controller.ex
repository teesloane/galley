defmodule GalleyWeb.RecipeController do
  use GalleyWeb, :controller

  def new(conn, _params) do
    IO.inspect(_params)
    render(conn, "new.html")
  end

  def create(conn, %{"ingredient" => ingredient_params}) do
    IO.inspect("hi there from place")
  end

end
