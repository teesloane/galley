defmodule GalleyUtils do
  @moduledoc """
  Utils for Galley specific things.
  """

  def get_temp_id do
    :crypto.strong_rand_bytes(5)
    |> Base.url_encode64()
    |> binary_part(0, 5)
  end

  def slug(s) do
    s |> String.downcase() |> String.replace(" ", "-")
  end

  def get_thumbnail(img_file) do
    "#{Path.rootname(img_file)}_thumb#{Path.extname(img_file)}"
  end

  def pad_digit(d) do
    d_as_str = to_string(d)

    if String.length(d_as_str) == 1 do
      "0#{d_as_str}"
    else
      d_as_str
    end
  end

  def seconds_to_time_str(total_seconds) do
    hours = (total_seconds / 3600) |> trunc
    minutes = ((total_seconds - hours * 3600) / 60) |> trunc
    seconds = total_seconds - hours * 3600 - minutes * 60

    if hours > 0 do
      "#{prepend_zero_to_int(hours)}:#{prepend_zero_to_int(minutes)}:#{prepend_zero_to_int(seconds)}"
    else
      "#{prepend_zero_to_int(minutes)}:#{prepend_zero_to_int(seconds)}"
    end
  end

  def prepend_zero_to_int(i) do
    if i < 10 and i > -1 do
      "0#{to_string(i)}"
    else
      to_string(i)
    end
  end

  def trx_hour_and_min_to_seconds(hours, min) do
    s1 = hours * 60 * 60
    s2 = min * 60
    s1 + s2
  end

  def is_dev?() do
    Application.fetch_env!(:galley, :env) == :dev
  end

  def is_test?() do
    Application.fetch_env!(:galley, :env) == :test
  end

  def is_prod?() do
    Application.fetch_env!(:galley, :env) == :prod
  end
end
