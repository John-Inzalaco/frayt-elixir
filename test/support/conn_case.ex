defmodule FraytElixirWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FraytElixirWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      alias FraytElixirWeb.Router.Helpers, as: Routes
      alias FraytElixirWeb.API.V2x1.Router.Helpers, as: RoutesApiV2_1
      alias FraytElixirWeb.API.V2x2.Router.Helpers, as: RoutesApiV2_2
      import FraytElixir.{Factory, Guardian}
      import FraytElixirWeb.Test.LoginHelper
      import FraytElixir.Assertions.Map

      # The default endpoint for testing
      @endpoint FraytElixirWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(FraytElixir.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(FraytElixir.Repo, {:shared, self()})
    end

    {:ok,
     conn:
       Phoenix.ConnTest.build_conn()
       |> Plug.Conn.put_req_header("content-type", "application/json")}
  end
end
