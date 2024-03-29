defmodule Galley.RecipesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Galley.Recipes` context.
  """

  import Galley.AccountsFixtures
  alias Galley.Recipes

  @valid_attrs %{
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
      },

      "1" => %{
        "instruction" => "Fry the onions for 5 minuts",
        "temp_id" => "njwyI",
        "timer" => %{"hour" => "0", "minute" => "5"}
      }
    },
    "tags" => "baking, sweet",
    "time" => %{"hour" => "1", "minute" => "0"},
    "title" => "Boring onion muffins",
    "uploaded_images" => [],
    "yields" => "12 muffins"
  }

  @doc """
  Generate a recipe.
  """
  def recipe_fixture(attrs \\ %{}, user \\ user_fixture()) do
    {:ok, recipe} = Enum.into(attrs, @valid_attrs) |> Recipes.insert_recipe(user)
    recipe
  end

  def recipe_raw_data() do
    @valid_attrs
  end


  def valid_attrs, do: @valid_attrs
end
