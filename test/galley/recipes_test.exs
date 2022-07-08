defmodule Galley.RecipesTest do
  use Galley.DataCase

  alias Galley.Recipes

  describe "recipes" do
    import Galley.RecipesFixtures

    test "list_recipes/0 returns all recipes" do
      recipe = recipe_fixture()
      # NOTE, we can't just check list_recipes = [recipe] because there are
      # preloads/dynamic values (temp_ids) etc that are a bit of a paint to
      # remove. This way, at least test the count and the values of what was inserted.
      recipes = Recipes.list_recipes()
      recipe_1 = Enum.at(recipes, 0)
      assert Enum.count(recipes) == 1
      assert recipe_1.title == recipe.title
      assert recipe_1.notes == recipe.notes
    end

    test "get_recipe! returns the recipe fixture" do
      recipe = recipe_fixture()
      res = Recipes.get_recipe!(recipe.id)
      assert recipe.id == res.id
      assert recipe.slug == res.slug
      assert recipe.title == res.title
      assert Enum.count(recipe.ingredients) == Enum.count(res.ingredients)
      assert Enum.count(recipe.steps) == Enum.count(res.steps)
    end

    test "get_recipe_by_id_and_slug" do
      recipe = recipe_fixture()
      res = Recipes.get_recipe_by_id_and_slug!(recipe.id, recipe.slug)
      assert recipe.slug == res.slug
      assert recipe.id == res.id
      assert recipe.title == res.title
      assert %Galley.Accounts.User{} = res.user
    end

    # test "insert_recipe" do

    # end

    # test "change_recipe" do
    # end

    # test "update_recipe/2 with valid data updates the recipe" do
    #   recipe = recipe_fixture()

    #   update_attrs = %{
    #     author: "some updated author",
    #     cook_time: "some updated cook_time",
    #     prep_time: "some updated prep_time",
    #     source: "some updated source",
    #     title: "some updated title",
    #     total_time: "some updated total_time",
    #     yields: "some updated yields"
    #   }

    #   assert {:ok, %Recipe{} = recipe} = Recipes.update_recipe(recipe, update_attrs)
    #   assert recipe.author == "some updated author"
    #   assert recipe.cook_time == "some updated cook_time"
    #   assert recipe.prep_time == "some updated prep_time"
    #   assert recipe.source == "some updated source"
    #   assert recipe.title == "some updated title"
    #   assert recipe.total_time == "some updated total_time"
    #   assert recipe.yields == "some updated yields"
    # end

    # test "update_recipe/2 with invalid data returns error changeset" do
    #   recipe = recipe_fixture()
    #   assert {:error, %Ecto.Changeset{}} = Recipes.update_recipe(recipe, @invalid_attrs)
    #   assert recipe == Recipes.get_recipe!(recipe.id)
    # end

    # test "delete_recipe/1 deletes the recipe" do
    #   recipe = recipe_fixture()
    #   assert {:ok, %Recipe{}} = Recipes.delete_recipe(recipe)
    #   assert_raise Ecto.NoResultsError, fn -> Recipes.get_recipe!(recipe.id) end
    # end

    # test "change_recipe/1 returns a recipe changeset" do
    #   recipe = recipe_fixture()
    #   assert %Ecto.Changeset{} = Recipes.change_recipe(recipe)
    # end
  end
end
