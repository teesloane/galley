defmodule Galley.RecipesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Galley.Recipes` context.
  """

  import Galley.AccountsFixtures
  alias Galley.Recipes.Recipe

  @valid_attrs %{
    ingredients: [
      %{
        ingredient: "onion",
        measurement: "lb",
        prep: "minced",
        quantity: "1",
        temp_id: "gTHDl"
      }
    ],
    notes: "",
    source: "test",
    steps: [
      %{
        instruction: "Cut the onions",
        temp_id: "njwyI",
        timer: %{hour: "0", minute: "0"}
      }
    ],
    tags: "spicy",
    time: %{hour: "1", minute: "0"},
    title: "test",
    uploaded_images: [],
    yields: "12 muffins"
  }

  @doc """
  Generate a recipe.
  """
  def recipe_fixture(attrs \\ %{}) do
    user = user_fixture()

    base = %{
      "ingredients" => %{
        "0" => %{
          "ingredient" => "onion",
          "measurement" => "lb",
          "prep" => "minced",
          "quantity" => "1",
          "temp_id" => "gTHDl"
        }
      },
      "notes" => "",
      "source" => "test",
      "steps" => %{
        "0" => %{
          "instruction" => "Cut the onions",
          "temp_id" => "njwyI",
          "timer" => %{"hour" => "0", "minute" => "0"}
        }
      },
      "tags" => "spicy",
      "time" => %{"hour" => "1", "minute" => "0"},
      "title" => "test",
      "uploaded_images" => [],
      "yields" => "12 muffins"
    }

    new_attrs = Enum.into(base, attrs)
    {:ok, recipe} = Galley.Recipes.insert_recipe(user, new_attrs)
    recipe
  end
end
