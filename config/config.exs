import Config

if config_env() == :test do
  config :ecto, json_library: JSON
  config :postgrex, json_library: JSON
  config :oban, json_library: JSON

  import_config "test.exs"
end
