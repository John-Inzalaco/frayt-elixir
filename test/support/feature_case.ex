defmodule FraytElixirWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by browser-based tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case
      use FraytElixir.DataCase
      use Wallaby.DSL
      import Wallaby.Feature
      import FraytElixir.Factory
      import FraytElixirWeb.Test.FeatureTestHelper
      import Wallaby.Query
      alias FraytElixirWeb.Test.SessionPage
    end
  end

  setup _tags do
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(FraytElixir.Repo, self())
    {:ok, %Wallaby.Session{} = session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
