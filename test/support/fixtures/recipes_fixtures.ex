defmodule Galley.RecipesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Galley.Recipes` context.
  """

  @doc """
  Generate a recipe.
  """
  def recipe_fixture(attrs \\ %{}) do
    {:ok, recipe} =
      attrs
      |> Enum.into(%{
        author: "some author",
        cook_time: "some cook_time",
        prep_time: "some prep_time",
        source: "some source",
        title: "some title",
        total_time: "some total_time",
        yields: "some yields"
      })
      |> Galley.Recipes.create_recipe()

    recipe
  end
end
