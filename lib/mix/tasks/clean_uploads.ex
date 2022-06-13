defmodule Mix.Tasks.Db.CleanUploads do
  use Mix.Task
  import Galley.Recipes
  @requirements ["app.start"]

  @shortdoc "Scans priv/static/uploads for unattached uploads"
  def run(_) do
    used_images = list_recipes()
    |> Enum.map(fn r -> r.uploaded_images end)
    |> List.flatten()
    |> Enum.map(fn i -> "priv/static#{i.url}" end)
    |> List.flatten()

    uploads = Path.wildcard("priv/static/uploads/*")
    uploads
      |> Enum.each(fn e ->
      if not Enum.member?(used_images, e) do
        File.rm(e)
      end
    end)
  end
end
