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
