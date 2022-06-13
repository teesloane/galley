defmodule Mix.Tasks.CleanUploads do
  use Mix.Task
  import Galley.Recipes
  import GalleyWeb.Router.Helpers, as: Routes

  @shortdoc "Scans priv/static/uploads for unattached uploads"
  def run(_) do
    used_images =
      list_recipes()
      |> Enum.map(fn recipe ->
        recipe.uploaded_images
        |> List.flatten()
      end)

    static_folder = Routes.static_path(socket, "/uploads")
    uploads = Path.wildcard("#{static_folder}/*")
    IO.inspect([used_images, uploads], label: ">>>>>>>>>>")
  end
end
