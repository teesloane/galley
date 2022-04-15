defmodule GalleyUtils do
  def get_temp_id do
    :crypto.strong_rand_bytes(5)
    |> Base.url_encode64()
    |> binary_part(0, 5)
  end

  def slug(s) do
    s |> String.downcase() |> String.replace(" ", "-")
  end

  def pad_digit(d) do
    d_as_str = to_string(d)

    if String.length(d_as_str) == 1 do
      "0#{d_as_str}"
    else
      d_as_str
    end
  end
end
