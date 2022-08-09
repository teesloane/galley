defmodule Galley.TimerServer do
  use GenServer
  alias Phoenix.PubSub

  # Implementations --

  @impl true
  def init(_) do
    decrement_all()
    cleanup_done()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_timer, user_id, timer_params}, state) do
    key = {user_id, timer_params.id}
    {:noreply, Map.put(state, key, timer_params)}
  end

  def handle_cast({:toggle_pause_timer_for_user, user_timer_tuple}, state) do
    state =
      Map.update!(state, user_timer_tuple, fn entry ->
        case entry.state do
          :running -> %{entry | state: :paused}
          :paused -> %{entry | state: :running}
          _ -> entry
        end
      end)

    {:noreply, state}
  end

  def handle_cast({:clear_all}, _state) do
    {:noreply, %{}}
  end

  @impl true
  def handle_call({:get_timers}, _, state) do
    {:reply, state, state}
  end

  def handle_call({:get_timers_for_user, user_id}, _, state) do
    reply =
      Enum.filter(state, fn {{u_id, _timer_id}, _timer} -> u_id == user_id end)
      |> Enum.map(fn {{_, timer_id}, timer} -> {timer_id, timer} end)
      |> Enum.into(%{})

    {:reply, reply, state}
  end

  def handle_call({:cancel_timer, user_timer_tuple}, _, state) do
    state = Map.delete(state, user_timer_tuple)
    success? = Map.get(state, user_timer_tuple) == nil
    {:reply, success?, state}
  end

  @impl true
  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(:cleanup_done, state) do
    cleanup_done()
    PubSub.broadcast(Galley.PubSub, topic(), :timer_cleanup)

    state =
      state
      |> Enum.reject(fn {_k, v} -> v.state == :done end)
      |> Enum.into(%{})

    {:noreply, state}
  end

  def handle_info(:decrement_all, state) do
    decrement_all()

    state =
      Enum.map(state, fn {key, val} ->
        cond do
          val.remaining_time_in_seconds == 0 ->
            reset_timer = %{val | state: :done, remaining_time_in_seconds: 0}
            {key, reset_timer}

          val.state == :running ->
            {key, %{val | remaining_time_in_seconds: val.remaining_time_in_seconds - 1}}

          true ->
            {key, val}
        end
      end)
      |> Enum.into(%{})

    if map_size(state) > 0 do
      PubSub.broadcast(Galley.PubSub, topic(), :tick)
    end

    {:noreply, state}
  end

  # Interface --
  #
  def topic do
    "Galley.Timer"
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def create_timer(user_id, timer_params) do
    GenServer.cast(__MODULE__, {:add_timer, user_id, timer_params})
  end

  def get_timers() do
    GenServer.call(__MODULE__, {:get_timers})
  end

  def get_timers_for_user(user_id) do
    GenServer.call(__MODULE__, {:get_timers_for_user, user_id})
  end

  def pause_timer(user_timer_tuple) do
    GenServer.cast(__MODULE__, {:toggle_pause_timer_for_user, user_timer_tuple})
  end

  def cancel_timer(user_timer_tuple) do
    GenServer.call(__MODULE__, {:cancel_timer, user_timer_tuple})
  end

  def stop do
    send(__MODULE__, :stop)
  end

  def clear_all() do
    GenServer.cast(__MODULE__, {:clear_all})
  end

  defp decrement_all() do
    Process.send_after(self(), :decrement_all, 1000)
  end

  defp cleanup_done() do
    Process.send_after(self(), :cleanup_done, 10 * 60 * 1000)
  end
end
