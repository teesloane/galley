# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Galley.Repo.insert!(%Galley.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
#

Galley.Accounts.register_user(%{
  email: "weakty@theiceshelf.com",
  username: "weakty",
  password: "password1234"
})

user = Galley.Accounts.get_user_by_email("weakty@theiceshelf.com")

## === Recipe ==================================================================

# I turned this off because the ari's garden script populates things nicely!

# y =
#   Galley.Recipes.insert_recipe(
#     user,
#     %{
#       "ingredients" => %{
#         "0" => %{
#           "ingredient" => "coconut oil",
#           "measurement" => "tbsp",
#           "quantity" => "1",
#           "temp_id" => "1c6gb"
#         },
#         "1" => %{
#           "ingredient" => "mixed fresh vegetables",
#           "measurement" => "cups",
#           "quantity" => "4",
#           "temp_id" => "2c6gb"
#         },
#         "2" => %{
#           "ingredient" => "Red lentils (uncooked)",
#           "measurement" => "cup",
#           "quantity" => "1/2",
#           "temp_id" => "3c6gb"
#         },
#         "3" => %{
#           "ingredient" => "water",
#           "measurement" => "cup",
#           "quantity" => "1/2",
#           "temp_id" => "4c6gb"
#         },
#         "4" => %{
#           "ingredient" => "diced tomato",
#           "measurement" => "oz",
#           "quantity" => "14",
#           "temp_id" => "5c6gb"
#         },
#         "5" => %{
#           "ingredient" => "coconut milk",
#           "measurement" => "oz",
#           "quantity" => "14",
#           "temp_id" => "6c6gb"
#         },
#         "6" => %{
#           "ingredient" => "garlic powder",
#           "measurement" => "tsp",
#           "quantity" => "1.5",
#           "temp_id" => "7c6gb"
#         },
#         "7" => %{
#           "ingredient" => "minced onion",
#           "measurement" => "tsp",
#           "quantity" => "1.5",
#           "temp_id" => "8c6gb"
#         },
#         "8" => %{
#           "ingredient" => "curry powder",
#           "measurement" => "tbsp",
#           "quantity" => "1",
#           "temp_id" => "9c6gb"
#         },
#         "9" => %{
#           "ingredient" => "sea salt",
#           "measurement" => "tsp",
#           "quantity" => "1",
#           "temp_id" => "L16gb"
#         },
#         "10" => %{
#           "ingredient" => "pepper",
#           "measurement" => "pinch",
#           "quantity" => "1",
#           "temp_id" => "L96gb"
#         }
#       },
#       "notes" => "",
#       "source" => "https://ohsheglows.com/2017/07/21/8-minute-pantry-dal-two-ways/",
#       "steps" => %{
#         "0" => %{
#           "instruction" => "Melt coconut oil in a large pot.",
#           "temp_id" => "qI0-E"
#         },
#         "1" => %{
#           "instruction" =>
#             "Peel (if necessary) and dice vegetables into 1/2 inch pieces. Add to pot and stir.",
#           "temp_id" => "qI0-D"
#         },
#         "2" => %{
#           "instruction" =>
#             "Add the rest of the ingredients (coconut milk, diced tomato, garlic powder, minced onion, curry powder lentils).",
#           "temp_id" => "qI1-D"
#         },
#         "3" => %{
#           "instruction" => "Bring to a boil and the reduce heat to medium.",
#           "temp_id" => "qI2-D"
#         },
#         "4" => %{
#           "instruction" =>
#             "Cook for 18-30 minutes. Stir and taste frequently. Remove from heat when vegetables are tender.",
#           "temp_id" => "qI3-D",
#           "timer" => %{"hour" => "0", "minute" => "18"}
#         },
#         "5" => %{
#           "instruction" => "Serve over rice. Optional: Garnish with cilantro and lime.",
#           "temp_id" => "qI4-D"
#         }
#       },
#       "tags" => "",
#       "time" => %{"hour" => "0", "minute" => "0"},
#       "title" => "Pantry Dahl",
#       "uploaded_images" => [],
#       "yields" => "4 servings"
#     }
#   )
