def get_json(filename) do
  with {:ok, body} <- File.read(filename),
       {:ok, json} <- Poison.decode, do {:ok, json}
 end
