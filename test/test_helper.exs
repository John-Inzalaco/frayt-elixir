{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, "http://localhost:3000")
ExUnit.start(capture_log: true)

MockMe.start()
mock_routes = FraytElixir.Test.Mocks.Zapier.routes()
MockMe.add_routes(mock_routes)

MockMe.start_server()

Ecto.Adapters.SQL.Sandbox.mode(FraytElixir.Repo, :manual)
