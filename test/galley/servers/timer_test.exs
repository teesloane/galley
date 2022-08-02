defmodule Galley.TimerServerTest do
  use Galley.DataCase
  alias Galley.TimerServer, as: SUT

  @timer_fixture %{
    has_timer: true,
    hour: 1,
    minute: 30,
    state: :new,
    id: "foo",
    remaining_time_in_seconds: 5400
  }

  test "It initializes a genserver with an empty map" do
    assert SUT.init(nil) == {:ok, %{}}
  end

  test "Creation/Getting of timers" do
    SUT.clear_all()
    SUT.create_timer(1, @timer_fixture)
    timers = SUT.get_timers()
    # we can only assert that this is more than
    assert timers |> Enum.count() == 1

    assert %{
             {1, "foo"} => %{
               has_timer: true,
               hour: 1,
               id: "foo",
               minute: 30,
               remaining_time_in_seconds: 5400,
               state: :new
             }
           } == timers
  end
end
