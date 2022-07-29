defmodule GalleyWeb.RecipeLiveTest do
  use GalleyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Galley.RecipesFixtures
  import Galley.AccountsFixtures
  alias Galley.Recipes

  # logs in, creates a user, a recipe, and goes to the route we want to test (through a callback.)
  defp run_setup(ctx, route_fn) do
    user = user_fixture()

    conn =
      ctx.conn
      |> Map.replace!(:secret_key_base, GalleyWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> log_in_user(user)

    recipe = recipe_fixture(%{}, user)
    ctx = Enum.into(%{recipe: recipe, user: user, conn: conn, view: nil, html: nil}, ctx)
    path = route_fn.(ctx)
    {:ok, view, html} = live(conn, path)
    %{ctx | view: view, html: html}
  end

  describe "Index" do
    setup ctx do
      run_setup(ctx, fn ctx -> Routes.recipe_index_path(ctx.conn, :index) end)
    end

    test "Lists recipes", %{html: html} do
      assert html =~ "Recipes"
      assert html =~ "Search recipes by name.."
      assert html =~ "Search by tags"
      assert html =~ "All"
    end

    test "visiting with params runs filters", %{conn: conn} do
      path = Routes.recipe_index_path(conn, :index, filter: "My Recipes")
      {:ok, _index_live, html} = live(conn, path)
      assert html =~ "Your recipes (1)"
    end

    test "search query returns no results", %{conn: conn} do
      path = Routes.recipe_index_path(conn, :index, query: "dlkfjaeifaldkgs")
      {:ok, _index_live, html} = live(conn, path)
      assert html =~ "No recipes found."
    end

    test "search query returns recipe_fixture", %{conn: conn} do
      path = Routes.recipe_index_path(conn, :index, query: "muffi")
      {:ok, view, html} = live(conn, path)
      assert html =~ "Recipes (1)"

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find("#recipe_list")
             |> Enum.count() == 1
    end

    test "search by tags returns recipe_fixture", %{conn: conn} do
      path = Routes.recipe_index_path(conn, :index, tags: "baking, lunch")
      {:ok, _view, html} = live(conn, path)
      assert html =~ "Recipes tagged with: baking, lunch (1)"
    end

    test "search non-existing-tag returns no results", %{conn: conn} do
      path = Routes.recipe_index_path(conn, :index, tags: "foo")
      {:ok, _view, html} = live(conn, path)
      assert html =~ "No recipes found."
    end

    test "clicking a recipe goes to recipelive show route.", ctx do
      path = Routes.recipe_index_path(ctx.conn, :index)
      {:ok, view, _html} = live(ctx.conn, path)
      expected_redirect = Routes.recipe_show_path(ctx.conn, :show, ctx.recipe, ctx.recipe.slug)
      element(view, "#recipe-#{ctx.recipe.id}") |> render_click()
      assert_redirect(view, expected_redirect)
    end
  end

  describe "Show" do
    setup ctx do
      run_setup(ctx, fn ctx ->
        Routes.recipe_show_path(ctx.conn, :show, ctx.recipe, ctx.recipe.slug)
      end)
    end

    test "Visiting a recipe shows expected dom content", ctx do
      assert ctx.view |> element("[data-test-id=show-heading]") |> render() =~ ctx.recipe.title
      assert ctx.view |> has_element?("[data-test-id=section-ingredients]")
      assert ctx.view |> has_element?("[data-test-id=section-instructions]")
      refute ctx.view |> has_element?("[data-test-id=additional-notes]")
      refute ctx.view |> has_element?("[data-test-id=section-photos]")
    end

    test "favouriting works", ctx do
      path = Routes.recipe_show_path(ctx.conn, :show, ctx.recipe, ctx.recipe.slug)

      # open and favourite the recipe
      {:ok, view, _html} = live(ctx.conn, path)
      assert view |> has_element?("button", "🤍")
      element(view, "button", "🤍") |> render_click()

      # revisit and try toggling off
      {:ok, view, _html} = live(ctx.conn, path)
      assert view |> has_element?("button", "❤️")
      element(view, "button", "❤") |> render_click()

      # revisit and ensure button is off.
      {:ok, view, _html} = live(ctx.conn, path)
      assert view |> has_element?("button", "🤍")
    end
  end

  describe "Edit/Update" do
    setup ctx do
      run_setup(ctx, fn ctx -> Routes.recipe_upsert_path(ctx.conn, :edit, ctx.recipe) end)
    end

    test "General markup expectations are met", ctx do
      assert ctx.html =~ "Edit - #{ctx.recipe.title}"
    end

    test "Running an update with a new title redirects to new url.", ctx do
      ctx.view |> form("#recipe-form", %{"recipe[title]" => "new title"}) |> render_change()
      ctx.view |> form("#recipe-form") |> render_submit()
      new_path = "/recipes/1/new-title"
      assert_redirect(ctx.view, new_path)

      {:ok, _view, html} = live(ctx.conn, new_path)
      assert html =~ "new title"
    end

    test "Updating a field (non title) redirects to same url and has the new content.", ctx do
      ctx.view |> form("#recipe-form", %{"recipe[yields]" => "100 hats"}) |> render_change()
      ctx.view |> form("#recipe-form") |> render_submit()
      expected_redirect = Routes.recipe_show_path(ctx.conn, :show, ctx.recipe, ctx.recipe.slug)
      assert_redirect(ctx.view, expected_redirect)

      {:ok, _view, html} = live(ctx.conn, expected_redirect)
      assert html =~ "Boring onion muffins"
      assert html =~ "100 hats"
    end

    test "ability to add instructions fields dynamically", ctx do
      assert ctx.view |> get_inputs_in_table("instructions-table", "textarea") == 1
      ## now add a instruction
      render_click(ctx.view, "add-instruction")
      assert ctx.view |> get_inputs_in_table("instructions-table", "textarea") == 2
      # now check that the counter works by adding 8 more steps.
      ctx.view |> form("#recipe-form", %{"recipe[__add_n_steps]" => "8"}) |> render_change()
      render_click(ctx.view, "add-instruction")
      assert ctx.view |> get_inputs_in_table("instructions-table", "textarea") == 10
    end

    test "ability to add ingredient fields dynamically", ctx do
      assert ctx.view |> get_inputs_in_table("ingredients-table", "input") == 6

      ## now add a instruction
      render_click(ctx.view, "add-ingredient")
      assert ctx.view |> get_inputs_in_table("ingredients-table", "input") == 11

      # now check that the counter works by adding 8 more steps.
      ctx.view |> form("#recipe-form", %{"recipe[__add_n_ingredients]" => "8"}) |> render_change()
      render_click(ctx.view, "add-ingredient")
      assert ctx.view |> get_inputs_in_table("ingredients-table", "input") == 51
    end

    test "Ability to delete recipes", ctx do
      assert Galley.Recipes.get_recipe!(ctx.recipe.id) !== nil
      render_click(ctx.view, "delete", %{id: ctx.recipe.id})

      assert_raise(
        Ecto.NoResultsError,
        fn -> Galley.Recipes.get_recipe!(ctx.recipe.id) end
      )
    end

    test "only user who created recipe can edit it.", ctx do
      user2 = user_fixture()

      conn =
        ctx.conn
        |> Map.replace!(:secret_key_base, GalleyWeb.Endpoint.config(:secret_key_base))
        |> init_test_session(%{})
        |> log_in_user(user2)

      # NOTE: creating this recipe with the user from the setup, not the user we are now logged in as!
      recipe = recipe_fixture(%{}, ctx.user)

      path = Routes.recipe_upsert_path(conn, :edit, recipe)
      assert {:error, redirect_map} = live(conn, path)
      assert redirect_map == {:live_redirect, %{flash: %{}, to: "/"}}
    end
  end

  describe "Create" do
    setup ctx do
      run_setup(ctx, fn ctx -> Routes.recipe_upsert_path(ctx.conn, :new) end)
    end

    test "we have our default number of inputs showing", ctx do
      assert ctx.view |> get_inputs_in_table("ingredients-table", "input") == 25
      assert ctx.view |> get_inputs_in_table("instructions-table", "input") == 5
    end

    test "can create recipes", ctx do
      assert Recipes.count_recipes() == 1

      raw_data = %{
        "title" => "my new recipe",
        "ingredients" => %{
          "0" => %{
            "ingredient" => "apples",
            "measurement" => "lb",
            "prep" => "chopped",
            "quantity" => "1"
          },
          "1" => %{
            "ingredient" => "cinnamon",
            "measurement" => "tsp",
            "prep" => "",
            "quantity" => "1"
          }
        },
        "steps" => %{
          "0" => %{
            "instruction" => "Cut the apples and sprinkle with cinnaomon",
            "timer" => %{"hour" => "0", "minute" => "0"}
          }
        },
        "source" => "a cookbook",
        "tags" => "spicy, vegetarian",
        "time" => %{"hour" => "1", "minute" => "0"},
        "yields" => "4 servings"
      }

      assert {:error, map} = ctx.view |> form("#recipe-form", recipe: raw_data) |> render_submit()
      assert {:live_redirect, redirect_map} = map
      assert redirect_map.to == "/recipes/2/my-new-recipe"
      assert Recipes.count_recipes() == 2

      most_recent = Recipes.list_recipes() |> List.last()
      assert most_recent.ingredients |> Enum.count() == 2
      assert most_recent.steps |> Enum.count() == 1
    end
  end

  defp get_inputs_in_table(view, name, input_type) do
    element(view, "[data-test-id=#{name}]")
    |> render()
    |> Floki.find(input_type)
    |> Enum.count()
  end
end
