defmodule Galley.Recipes.MigrateAris do
  def do_migration(sleep \\ 0) do
    # for http requests to get ag images.
    IO.puts("GLOG: migrating ari's garden...")
    :inets.start()
    :ssl.start()
    # turn off annoying sql
    Logger.configure(level: :info)
    # open up the json file
    json_file = Path.join(:code.priv_dir(:galley), "/repo/aris_garden.json")
    me = Galley.Accounts.get_user_by_email("weakty@theiceshelf.com")
    {:ok, json} = get_json(json_file)

    for {slug, recipe_data} <- json["recipes"],
        recipe = ari_to_galley(slug, recipe_data),
        do: insert_recipe(recipe, me, sleep)
  end

  defp insert_recipe(recipe, me, sleep) do
    case Galley.Recipes.insert_recipe(recipe, me, async_upload: false, timer: sleep) do
      {:ok, recipe} ->
        {:noreply, recipe}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "error...........")
        {:noreply, changeset}
    end
  end

  def ari_to_galley(slug, ag) do
    %{
      "ingredients" => parse_ingredients(ag["ingredients"]),
      "notes" => "",
      "source" => ag["original_recipe"],
      "steps" => parse_steps(ag["instructions"]),
      "tags" => "#{ag["belongs_to"]}, #{ag["meal_type"]}",
      "time" => parse_timer(ag["time"]),
      "title" => ag["name"],
      "uploaded_images" => parse_images(slug, ag["imgs"]),
      "yields" => parse_yields(ag["serves"])
    }
  end

  defp parse_yields(serves) do
    if String.length(serves) === 1 do
      "#{serves} servings"
    else
      serves
    end
  end

  defp parse_images(slug, ag_imgs) do
    imgs =
      ag_imgs
      |> Enum.with_index()
      |> Enum.map(fn {i, _index} ->
        key = "#{slug}-#{i}"

        img_url =
          "https://raw.githubusercontent.com/theiceshelf/arisgarden/master/src/assets/imgs/#{key}"

        download_img_to_static_folder(img_url)

        local_path = "#{Galley.Application.get_uploads_folder()}/#{key}"

        %{
          "is_hero" => false,
          "key_s3" => key,
          "is_local" => true,
          "local_path" => local_path,
          "url" => local_path,
          "url_thumb" => ""
        }
      end)

    hero_key = "#{slug}-hero.JPG"

    img_url =
      "https://raw.githubusercontent.com/theiceshelf/arisgarden/master/src/assets/imgs/#{hero_key}"

    download_img_to_static_folder(img_url)
    local_path = "#{Galley.Application.get_uploads_folder()}/#{hero_key}"

    # grab the hero, which isn't part of the imgs url.
    old_hero_img = %{
      "is_hero" => true,
      "key_s3" => hero_key,
      "is_local" => true,
      "local_path" => local_path,
      "url" =>
        "https://raw.githubusercontent.com/theiceshelf/arisgarden/master/src/assets/imgs/#{hero_key}",
      "url_thumb" =>
        "https://raw.githubusercontent.com/theiceshelf/arisgarden/master/src/assets/imgs/#{hero_key}"
    }

    [old_hero_img | imgs]
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
             "prep" => ingr["prep"],
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

  def download_img_to_static_folder(img_url) do
    img_output = "#{Galley.Application.get_uploads_folder()}/#{Path.basename(img_url)}"

    :httpc.request(:get, {img_url |> String.to_charlist(), []}, [],
      stream: img_output |> String.to_charlist()
    )
  end

  def get_json(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end
end
