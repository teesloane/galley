defmodule Galley.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # we do this here because fly.io can'd do release script with migrations and sqlite.
    Galley.Release.migrate()
    create_uploads_folder()

    children = [
      # Start the Ecto repository
      Galley.Repo,
      # Start the Telemetry supervisor
      GalleyWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Galley.PubSub},
      # Start the Endpoint (http/https)
      GalleyWeb.Endpoint
      # Start a worker by calling: Galley.Worker.start_link(arg)
      # {Galley.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Galley.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GalleyWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def create_uploads_folder() do
    File.mkdir_p!(get_uploads_folder())
  end

  def get_uploads_folder() do
    Path.join([:code.priv_dir(:galley), "static", "uploads"])
  end

  def get_bucket() do
    cond do
      GalleyUtils.is_dev?() -> "theiceshelf-galley-dev"
      GalleyUtils.is_prod() -> "theiceshelf-galley"
    end
  end
end
