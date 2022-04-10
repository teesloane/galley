defmodule Galley.RecipesTest do
  use Galley.DataCase

  alias Galley.Recipes

  describe "recipes" do
    alias Galley.Recipes.Recipe

    import Galley.RecipesFixtures

    @invalid_attrs %{
      author: nil,
      cook_time: nil,
      prep_time: nil,
      source: nil,
      title: nil,
      total_time: nil,
      yields: nil
    }

    test "list_recipes/0 returns all recipes" do
      recipe = recipe_fixture()
      assert Recipes.list_recipes() == [recipe]
    end

    test "get_recipe!/1 returns the recipe with given id" do
      recipe = recipe_fixture()
      assert Recipes.get_recipe!(recipe.id) == recipe
    end

    test "create_recipe/1 with valid data creates a recipe" do
      valid_attrs = %{
        author: "some author",
        cook_time: "some cook_time",
        prep_time: "some prep_time",
        source: "some source",
        title: "some title",
        total_time: "some total_time",
        yields: "some yields"
      }

      assert {:ok, %Recipe{} = recipe} = Recipes.create_recipe(valid_attrs)
      assert recipe.author == "some author"
      assert recipe.cook_time == "some cook_time"
      assert recipe.prep_time == "some prep_time"
      assert recipe.source == "some source"
      assert recipe.title == "some title"
      assert recipe.total_time == "some total_time"
      assert recipe.yields == "some yields"
    end

    test "create_recipe/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Recipes.create_recipe(@invalid_attrs)
    end

    test "update_recipe/2 with valid data updates the recipe" do
      recipe = recipe_fixture()

      update_attrs = %{
        author: "some updated author",
        cook_time: "some updated cook_time",
        prep_time: "some updated prep_time",
        source: "some updated source",
        title: "some updated title",
        total_time: "some updated total_time",
        yields: "some updated yields"
      }

      assert {:ok, %Recipe{} = recipe} = Recipes.update_recipe(recipe, update_attrs)
      assert recipe.author == "some updated author"
      assert recipe.cook_time == "some updated cook_time"
      assert recipe.prep_time == "some updated prep_time"
      assert recipe.source == "some updated source"
      assert recipe.title == "some updated title"
      assert recipe.total_time == "some updated total_time"
      assert recipe.yields == "some updated yields"
    end

    test "update_recipe/2 with invalid data returns error changeset" do
      recipe = recipe_fixture()
      assert {:error, %Ecto.Changeset{}} = Recipes.update_recipe(recipe, @invalid_attrs)
      assert recipe == Recipes.get_recipe!(recipe.id)
    end

    test "delete_recipe/1 deletes the recipe" do
      recipe = recipe_fixture()
      assert {:ok, %Recipe{}} = Recipes.delete_recipe(recipe)
      assert_raise Ecto.NoResultsError, fn -> Recipes.get_recipe!(recipe.id) end
    end

    test "change_recipe/1 returns a recipe changeset" do
      recipe = recipe_fixture()
      assert %Ecto.Changeset{} = Recipes.change_recipe(recipe)
    end
  end
end
