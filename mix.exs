defmodule FraytElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :frayt_elixir,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: Mix.env() == :test
      ],
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: :covertool, summary: true],
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FraytElixir.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :ex_machina,
        :timex,
        :faker,
        :singleton,
        :abacus
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.9"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, "~> 0.16", override: true},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.1"},
      {:cors_plug, "~> 2.0"},
      {:google_maps, github: "Frayt-Technologies/google_maps", tag: "0.11.1"},
      {:comeonin, "~> 5.3.1"},
      {:argon2_elixir, ">= 0.0.0"},
      {:ueberauth, "~> 0.6"},
      {:ueberauth_identity, "~> 0.3.0"},
      {:guardian, "~> 2.1.1"},
      {:guardian_db, "~> 2.0"},
      {:ex_machina, "~> 2.7"},
      {:hound, "~> 1.0"},
      {:stripity_stripe, "~> 2.8.0"},
      {:phoenix_live_view, "~> 0.15.4"},
      {:phoenix_live_dashboard, "~> 0.4"},
      {:floki, "~> 0.19"},
      {:wallaby, "~> 0.28.0", [runtime: false, only: [:ci, :test]]},
      {:proper_case, "~> 1.3.1"},
      {:bamboo, "~> 1.5"},
      {:waffle, "~> 1.1.3"},
      {:ex_aws, "~> 2.1.3"},
      {:ex_aws_s3, "~> 2.1.0"},
      {:hackney, "~> 1.17.0"},
      {:sweet_xml, "~> 0.6.6"},
      {:waffle_ecto, "~> 0.0.8"},
      {:geo, "~> 3.3.3"},
      {:geo_postgis, "~> 3.3.1"},
      {:one_signal, "~> 0.0.9"},
      {:httpoison, "1.8.0", override: true},
      {:ecto_enum, "~> 1.4"},
      {:slack, "~> 0.23.5"},
      {:routific, github: "Frayt-Technologies/routific", tag: "0.1.4"},
      {:ex_twilio, "~> 0.8.1"},
      {:csv, "~> 2.3"},
      {:params, "~> 2.0"},
      {:sentry, "~> 7.0"},
      {:appsignal_phoenix, "~> 2.0.0"},
      {:phoenix_swagger, "~> 0.8"},
      # Optional :phoenix_swagger dependancy
      {:ex_json_schema, "~> 0.5"},
      {:open_api_spex, "~> 3.11"},
      {:redirect, "~> 0.3.0"},
      {:timex, "~> 3.0"},
      {:hammer, "~> 6.0"},
      {:hammer_plug, "~> 2.1"},
      {:ex_audit, github: "ZennerIoT/ex_audit"},
      {:premailex, "~> 0.3.0"},
      {:ex_phone_number, "~> 0.2"},
      # Manual override since ex_audit has not updated for ecto 3.5. ecto can be romoved from deps when ex_audit has updated
      {:ecto, "~> 3.6.2", override: true},
      # Manual override since hammer_plug has not updated deps
      {:plug, "~> 1.12"},
      {:phoenix_live_session, "~> 0.1"},
      {:holidefs, github: "Frayt-Technologies/holidefs", tag: "v0.3.4"},
      {:html_sanitize_ex, "~> 1.3.0-rc3"},
      {:ex_crypto, github: "ntrepid8/ex_crypto", ref: "0915c274503f9fc6d6f5fab8c98467e7414cf8fc"},
      {:ecto_nested_changeset, "~> 0.2.0"},
      {:faker, "~> 0.17"},
      {:libcluster, "~> 3.3.1"},
      {:nebulex, "~> 2.4"},
      {:shards, "~> 1.0"},
      {:oban, "~> 2.12"},
      {:singleton, "~> 1.3.0"},
      {:geocalc, "~> 0.8.4"},
      {:abacus, "~> 2.0.0"},
      {:joken, "~> 2.5.0"},
      {:covertool, "~> 2.0.4", only: [:test, :ci], runtime: false, app: false},
      {:credo, "~> 1.6", only: [:dev, :test, :ci], runtime: false},
      {:bodyguard, "~> 2.2"},
      {:mock_me, "~> 0.2", [only: [:test, :ci], runtime: false]},
      {:fun_with_flags, "~> 1.10.1"},
      {:fun_with_flags_ui, "~> 0.8"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.seed": ["run priv/repo/seeds.#{Mix.env()}.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      boogity: ["clean", "compile"],
      "ecto.drop_and_migrate": ["ecto.drop", "ecto.create", "ecto.migrate"],
      test: [
        "assets.compile --quiet",
        "ecto.create --quiet",
        "ecto.migrate",
        "test"
      ],
      "assets.compile": &compile_assets/1,
      "ecto.migrate_monthly": ["run -e 'FraytElixir.Workers.MonthlyMigrations.run_migrations()'"],
      "ecto.migrate": ["ecto.migrate"]
    ]
  end

  defp compile_assets(_) do
    Mix.shell().cmd("cd assets && ./node_modules/.bin/webpack --mode development",
      quiet: true
    )
  end
end
