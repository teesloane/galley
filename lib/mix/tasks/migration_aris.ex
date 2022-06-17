defmodule Mix.Tasks.Db.MigrateAris do
  use Mix.Task

  @requirements ["app.start"]
  @shortdoc "Migrate from Ari's garden"
  @spec run(any) :: any
  def run(_) do
    json_file = Path.join(:code.priv_dir(:galley), "/repo/aris_garden.json")
    me = Galley.Accounts.get_user_by_email("weakty@theiceshelf.com")
    {:ok, json} = get_json(json_file)

    for {_name, recipe_data} <- json["recipes"],
        recipe = ari_to_galley(recipe_data),
        do: insert_recipe(me, recipe)
  end

  defp insert_recipe(me, recipe) do
    case Galley.Recipes.insert_recipe(me, recipe) do
      {:ok, _recipe} ->
        {:noreply, _recipe}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "error...........")
        {:noreply, changeset}
    end
  end

  @spec ari_to_galley(nil | maybe_improper_list | map) :: %{optional(<<_::32, _::_*8>>) => any}
  def ari_to_galley(ag) do
    %{
      "ingredients" => parse_ingredients(ag["ingredients"]),
      "notes" => "",
      "source" => ag["original_recipe"],
      "steps" => parse_steps(ag["instructions"]),
      "tags" => "#{ag["belongs_to"]}, #{ag["meal_type"]}",
      "time" => parse_timer(ag["time"]),
      "title" => ag["name"],
      "uploaded_images" => [
        %{
          "is_hero" => true,
          "key_s3" => "<local_file>",
          "url" => "/uploads/live_view_upload-1655424290-957761377085798-1"
        }
      ],
      "yields" => ag["serves"]
    }
  end

  defp parse_steps(ag_steps) do
    for {step, index} <- Enum.with_index(ag_steps),
        {parsed_step, timer_str} = parse_single_step(step),
        into: %{},
        do:
          {index,
           %{
             "instruction" => parsed_step,
             "temp_id" => GalleyUtils.get_temp_id(),
             "timer" => timer_str |> parse_timer
           }}
  end

  # takes a string such as:
  # "[&: 4. Simmer | 00:10:00] Mix the [#: sugar-white | sugar], [#: water | water], [#: salt | salt]
  # and ginger slices and simmer for 10 minutes.
  #
  # and parses out a data structure of:
  # %{
  #   reconstructed_step: "Mix the sugar, water, salt and ginger slices and simmer for 10 minutes",
  #   timer: parse_time
  #   }
  def parse_single_step(step) do
    step_list = step |> String.graphemes()

    step_data =
      Enum.reduce(
        step_list,
        %{
          output: "",
          capturing: false,
          capturing_timer: false,
          capturing_ingredient: false,
          capturing_ingr_string: false,
          timer: ""
        },
        fn item, acc ->
          case item do
            "[" ->
              %{acc | output: acc.output, capturing: true}

            "]" ->
              %{
                acc
                | output: acc.output,
                  capturing: false,
                  capturing_ingredient: false,
                  capturing_ingr_string: false,
                  capturing_timer: false
              }

            "&" ->
              if acc.capturing do
                %{acc | capturing_timer: true}
              else
                acc
              end

            "#" ->
              if acc.capturing do
                %{acc | capturing_ingredient: true}
              else
                acc
              end

            "|" ->
              if acc.capturing && acc.capturing_ingredient do
                %{acc | capturing_ingr_string: true}
              else
                acc
              end

            _ ->
              if acc.capturing do
                cond do
                  acc.capturing_timer -> %{acc | timer: acc.timer <> item}
                  acc.capturing_ingr_string -> %{acc | output: acc.output <> item}
                  acc.capturing_ingredient -> %{acc | output: acc.output}
                  true -> acc
                end
              else
                %{acc | output: acc.output <> item}
              end
          end
        end
      )

    # trim the string, removing any consecutive 2x white space.
    {
      String.trim(step_data.output) |> String.split("  ") |> Enum.join(" "),
      step_data.timer |> String.split() |> List.last()
    }
  end

  defp parse_ingredients(ag_ingrs) do
    for {ingr, index} <- Enum.with_index(ag_ingrs),
        into: %{},
        do:
          {index,
           %{
             "ingredient" => ingr["ingredient"] |> String.downcase(),
             "measurement" => ingr["unit"],
             "quantity" => map_get_string(ingr, "quantity"),
             "temp_id" => GalleyUtils.get_temp_id()
           }}
  end

  defp parse_timer(nil), do: %{"hour" => 0, "minute" => 0}

  defp parse_timer(timer_str) do
    if String.length(timer_str) !== 8 do
      %{"hour" => 0, "minute" => 0}
    else
      timer_ints =
        timer_str
        |> String.split(":")
        |> Enum.map(&Integer.parse/1)
        |> Enum.map(fn i -> elem(i, 0) end)

      # timer_ints
      %{"hour" => Enum.at(timer_ints, 0), "minute" => Enum.at(timer_ints, 1)}
    end
  end

  defp map_get_string(m, k) do
    if Map.get(m, k) === "" do
      "1"
    else
      Map.get(m, k)
    end
  end

  # take the imgs array and construct link to raw jpg on github (for now)
  # and return:
  #
  #   %{
  #     "is_hero" => true,
  #     "key_s3" => "<interpolate>",
  #     "url" => "<github url>"
  #   }
  # defp upload_images() do
  # end

  def get_json(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end
end
