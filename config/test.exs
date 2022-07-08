import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :galley, Galley.Repo,
  database: Path.expand("../galleydata_dev_test.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :galley, GalleyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cx/KS59WcXepSc9Hw5Sol2vWiKY9FPcGSobiIOqXic5xncVB3g/8ygcDOlQQ2Hdf",
  server: false

config :galley, env: config_env()

# In test we don't send emails.
config :galley, Galley.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
