defmodule GalleyUtils do
   def get_temp_id do
    :crypto.strong_rand_bytes(5)
    |> Base.url_encode64()
    |> binary_part(0, 5)
   end

   def slug(s) do
   s |> String.downcase() |> String.replace(" ", "-")
   end
end
