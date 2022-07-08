defmodule Galley.RecipesTest do
  use Galley.DataCase

  alias Galley.Recipes
  alias Galley.Recipes.Recipe

  describe "recipes" do
    import Galley.RecipesFixtures
    import Galley.AccountsFixtures

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

    test "get_recipe_slug" do
      recipe = recipe_fixture()
      res = Recipes.get_recipe_by_slug(recipe.slug)
      assert recipe.slug == res.slug
      assert recipe.id == res.id
      assert recipe.title == res.title
    end

    test "get_recipe_by_id_and_slug" do
      recipe = recipe_fixture()
      res = Recipes.get_recipe_by_id_and_slug!(recipe.id, recipe.slug)
      assert recipe.slug == res.slug
      assert recipe.id == res.id
      assert recipe.title == res.title
      assert %Galley.Accounts.User{} = res.user
    end

    test "insert_recipe" do
      u = user_fixture()
      valid_attrs = valid_attrs()
      assert {:ok, %Recipe{} = recipe} = Recipes.insert_recipe(valid_attrs, u)
      assert recipe.source == "test"
      assert recipe.title == "Boring onion muffins"
      assert recipe.slug == "boring-onion-muffins"
    end

    test "search_recipe" do
      # create multiple users.
      u1 = user_fixture()
      u2 = user_fixture()

      # create several recipes.
      r1 =
        recipe_fixture(
          %{
            "title" => "tofu scramble (u1)",
            "tags" => "",
            "time" => %{"hour" => "0", "minute" => "25"}
          },
          u1
        )

      r2 =
        recipe_fixture(
          %{
            "title" => "oatmeal (u1)",
            "tags" => "healthy, boring, easy",
            "time" => %{"hour" => "0", "minute" => "20"}
          },
          u1
        )

      _r3 = recipe_fixture(%{"title" => "muffins (u2)", "tags" => "breakfast, wholesome"}, u2)

      _r4 =
        recipe_fixture(
          %{"title" => "slow cooked stuff", "time" => %{"hour" => "5", "minute" => "0"}},
          u1
        )

      prm = %{"query" => "", "tags" => "", "filter" => ""}

      # -- Test: Search --

      # no search params == all results
      res = Recipes.search_recipes(prm, u1.id)
      assert length(res) == 4

      # random query == no results
      res = Recipes.search_recipes(%{prm | "query" => "foobar"}, u1.id)
      assert length(res) == 0

      res = Recipes.search_recipes(%{prm | "query" => "scram"}, u1.id)
      assert length(res) == 1
      assert List.first(res).title == "tofu scramble (u1)"

      # partial spelling
      res = Recipes.search_recipes(%{prm | "query" => "ram"}, u1.id)
      assert length(res) == 1

      # misspelling
      res = Recipes.search_recipes(%{prm | "query" => "scrm"}, u1.id)
      assert length(res) == 0

      # -- Test: Tags --

      res = Recipes.search_recipes(%{prm | "tags" => "breakfast"}, u1.id)
      assert length(res) == 1
      assert List.first(res).title == "muffins (u2)"

      res = Recipes.search_recipes(%{prm | "tags" => "breakfast, healthy"}, u1.id)
      assert length(res) == 2

      # -- Test: Filters --

      # Filters: All, My Recipes, Under an hour, Under 30 minutes, Recently posted, My favourites
      res = Recipes.search_recipes(%{prm | "filter" => "Under 30 minutes"}, u1.id)
      assert length(res) == 2

      res = Recipes.search_recipes(%{prm | "filter" => "Under an hour"}, u1.id)
      assert length(res) == 3

      res = Recipes.search_recipes(%{prm | "filter" => "My Recipes"}, u1.id)
      assert length(res) == 3

      res = Recipes.search_recipes(%{prm | "filter" => "My Recipes"}, u2.id)
      assert length(res) == 1

      res = Recipes.search_recipes(%{prm | "filter" => "My favourites"}, u2.id)
      assert length(res) == 0

      # favorite some recipes for a user.

      Recipes.favourite_recipe(%{user_id: u2.id, recipe_id: r1.id})
      Recipes.favourite_recipe(%{user_id: u2.id, recipe_id: r2.id})
      res = Recipes.search_recipes(%{prm | "filter" => "My favourites"}, u2.id)
      assert length(res) == 2

      # -- Test: Filters + Search --
      res =
        Recipes.search_recipes(%{prm | "filter" => "Under 30 minutes", "query" => "oat"}, u1.id)

      assert length(res) == 1

      # under 30 minute exists, but nothing should show when there is a query
      res =
        Recipes.search_recipes(
          %{prm | "filter" => "Under 30 minutes", "query" => "foobar"},
          u1.id
        )

      assert length(res) == 0

      # -- Test: Tags + Filters --

      res =
        Recipes.search_recipes(%{prm | "filter" => "Under an hour", "tags" => "healthy"}, u1.id)

      assert length(res) == 1

      # -- Test: Search + Tags --

      res = Recipes.search_recipes(%{prm | "query" => "oat", "tags" => "healthy"}, u1.id)

      assert length(res) == 1

      res = Recipes.search_recipes(%{prm | "query" => "xyz", "tags" => "healthy"}, u1.id)

      assert length(res) == 0
      #
      # -- Test: Search + Tags + Filters --
      res =
        Recipes.search_recipes(
          %{"query" => "oat", "tags" => "healthy", "filter" => "Under an hour"},
          u1.id
        )

      assert length(res) == 1

      res =
        Recipes.search_recipes(
          %{"query" => "oat", "tags" => "food", "filter" => "Under an hour"},
          u1.id
        )

      assert length(res) == 0
    end

    test "favourite_recipe" do
      {u, recipe} = make_recipe()
      favourite_res = Recipes.favourite_recipe(%{user_id: u.id, recipe_id: recipe.id})
      assert {:ok, %Recipes.Favourite{}} = favourite_res
    end

    test "unfavourite_recipe" do
      {u, recipe} = make_recipe()
      {:ok, favourite_res} = Recipes.favourite_recipe(%{user_id: u.id, recipe_id: recipe.id})

      assert {:ok, %Recipes.Favourite{} = r} = Recipes.unfavourite_recipe(favourite_res)
      assert r.recipe_id == favourite_res.recipe_id
      assert r.user_id == favourite_res.user_id
    end

    test "is_favourite?" do
      {u, recipe} = make_recipe()
      fav_params = %{user_id: u.id, recipe_id: recipe.id}
      assert Recipes.is_favourite?(fav_params) == false
      Recipes.favourite_recipe(fav_params)
      assert Recipes.is_favourite?(fav_params) == true
    end

    test "update_recipe" do
      {_u, recipe} = make_recipe()
      new_attrs = Enum.into(%{"title" => "foobar"}, valid_attrs())
      {:ok, update_recipe} = Recipes.update_recipe(recipe, new_attrs)
      assert update_recipe.title == "foobar"
      assert update_recipe.id == recipe.id
    end

    defp make_recipe() do
      u = user_fixture()
      valid_attrs = valid_attrs()
      {:ok, recipe} = Recipes.insert_recipe(valid_attrs, u)
      {u, recipe}
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
