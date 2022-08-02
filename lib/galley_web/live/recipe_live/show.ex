defmodule GalleyWeb.RecipeLive.Show do
  use GalleyWeb, :live_view

  alias Galley.Recipes
  alias Phoenix.PubSub
  @topic Galley.TimerServer.topic()

  @impl true
  def mount(_params, _session, socket) do
    # TODO: only subscribe if ... user has timers ?
    PubSub.subscribe(Galley.PubSub, @topic)
    {:ok, assign(socket, %{is_favourite: false})}
  end

  @impl true
  def handle_params(%{"id" => id, "slug" => slug}, _, socket) do
    recipe = Recipes.get_recipe_by_id_and_slug!(id, slug)

    {:noreply,
     socket
     |> assign(:page_title, "Galley - #{recipe.title}")
     |> assign(:recipe, recipe)
     |> align_timers_with_genserver()
     |> assign(:is_favourite, Recipes.is_favourite?(get_favourite_attrs(socket, recipe)))}
  end

  @impl true
  def handle_event("favourite-recipe", _params, socket) do
    res = Recipes.favourite_recipe(get_favourite_attrs(socket))

    case res do
      {:ok, _fav} ->
        {:noreply, socket |> assign(:is_favourite, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unfavourite-recipe", _params, socket) do
    res = Recipes.unfavourite_recipe(get_favourite_attrs(socket))

    case res do
      {:ok, _fav} ->
        {:noreply, socket |> assign(:is_favourite, false)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("create-timer", %{"value" => timer_uuid}, socket) do
    user = get_user_from_socket(socket)
    # get the recipe step where the timer uuid matches and send it to the genserver.
    step =
      Enum.find(socket.assigns.recipe.steps, fn step ->
        id = Map.get(step.timer, :id, nil)
        id == timer_uuid
      end)

    timer = %{step.timer | state: :running}
    Galley.TimerServer.create_timer(user.id, timer)

    {:noreply, socket}
  end

  def handle_event("cancel-timer", %{"value" => timer_uuid}, socket) do
    user = get_user_from_socket(socket)
    Galley.TimerServer.cancel_timer({user.id, timer_uuid})
    {:noreply, socket |> align_timers_with_genserver}
  end

  def handle_event("toggle-pause-timer", %{"value" => timer_uuid}, socket) do
    user = get_user_from_socket(socket)
    Galley.TimerServer.pause_timer({user.id, timer_uuid})

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, socket |> align_timers_with_genserver}
  end

  def handle_info(:timer_cleanup, socket) do
    {:noreply, socket |> align_timers_with_genserver}
  end

  def get_hero_img(recipe_images) do
    [default | _other] = recipe_images
    Enum.find(recipe_images, default, fn x -> x.is_hero == true end)
  end

  def get_other_images(recipe_images) do
    filtered = Enum.filter(recipe_images, fn x -> x.is_hero == false end)

    if length(filtered) == length(recipe_images) do
      # if no images are marked with is_hero: true...
      [_hero | non_hero] = recipe_images
      non_hero
    else
      filtered
    end
  end

  def render_timer_button(assigns) do
    s = assigns.timer.state

    cond do
      s == :running or s == :paused ->
        ~H"""
        <div class="flex">
        <button
          class={"btn-white mt-2 font-mono rounded-tr-none rounded-br-none text-xs #{if s == :paused, do: ~s|text-opacity-50|}"}
          value={assigns.timer.id}
          data-test-id={"timer-countdown-#{assigns.timer.id}"}
          phx-click="toggle-pause-timer"
        >
          <%= GalleyUtils.seconds_to_time_str(assigns.timer.remaining_time_in_seconds) %>
        </button>
        <button class="btn-white mt-2 text-xs border-l-none -ml-[1px] rounded-tl-none rounded-bl-none" phx-click="cancel-timer" value={assigns.timer.id}>✕</button>
        </div>
        """

      s == :new ->
        ~H"""
        <button
          class="btn-white mt-2"
          data-test-id={"timer-new-#{assigns.timer.id}"}
          value={assigns.timer.id}
          phx-click="create-timer"
        >
          <img
            width="8px"
            class="w-4 max-w-none"
            src={Routes.static_path(assigns.socket, "/images/clock.svg")}
          />
        </button>
        """

      s == :done ->
        ~H"""
        <button
          class="btn-white mt-2 text-xs font-mono"
          data-test-id={"timer-done-#{assigns.timer.id}"}
          value={assigns.timer.id}
          phx-click="acknowledge-timer"
        >
          <span class="absolute flex h-3 w-3">
            <span class="animate-[ping_1.5s_infinite] left-[-16px] top-[-10px] absolute inline-flex h-full w-full rounded-full bg-sky-400 opacity-75">
            </span>
            <span class="absolute left-[-16px] top-[-10px] inline-flex rounded-full h-3 w-3 bg-sky-500">
            </span>
          </span>

          <%= GalleyUtils.seconds_to_time_str(assigns.timer.remaining_time_in_seconds) %>
        </button>
        """
    end
  end

  defp get_favourite_attrs(socket) do
    user = get_user_from_socket(socket)

    %{
      user_id: user.id,
      recipe_id: socket.assigns.recipe.id
    }
  end

  defp get_favourite_attrs(socket, recipe) do
    user = get_user_from_socket(socket)

    %{
      user_id: user.id,
      recipe_id: recipe.id
    }
  end

  # loop over a recipe steps, and align the steps timers with genserver timers (if any)
  defp align_timers_with_genserver(socket) do
    user = get_user_from_socket(socket)
    recipe = socket.assigns.recipe
    gen_timers = Galley.TimerServer.get_timers_for_user(user.id)

    recipe =
      Map.update!(recipe, :steps, fn steps ->
        # loop over all the steps, and see if they have timers to patch in from gen_timers
        Enum.map(steps, fn step ->
          # if step has a timer... transform it
          if !has_timer?(step.timer) do
            %{step | timer: %{has_timer: false}}
          else
            existing_gen_timer? = Map.get(gen_timers, step.timer.id)

            cond do
              # is still in state from db.
              Map.get(step.timer, :state) == nil ->
                map_step_timers(step)

              # has a genserver timer ticking away
              existing_gen_timer? ->
                %{step | timer: existing_gen_timer?}

              # all else - reset it to be a new timer.
              true ->
                map_step_timers(step)
            end
          end
        end)
      end)

    assign(socket, :recipe, recipe)
  end

  defp map_step_timers(step) do
    if has_timer?(step.timer) do
      hour = step.timer.hour
      min = step.timer.minute

      t = %{
        has_timer: true,
        hour: hour,
        minute: min,
        state: :new,
        id: step.timer.id,
        remaining_time_in_seconds: GalleyUtils.trx_hour_and_min_to_seconds(hour, min)
      }

      %{step | timer: t}
    else
      %{step | timer: %{has_timer: false}}
    end
  end

  defp has_timer?(%{has_timer: false}), do: false

  defp has_timer?(m) do
    if m.hour == 0 and m.minute == 0, do: false, else: true
  end
end
