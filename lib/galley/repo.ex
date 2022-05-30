defmodule Galley.Repo do
  use Ecto.Repo,
    otp_app: :galley,
    adapter: Ecto.Adapters.SQLite3
end
