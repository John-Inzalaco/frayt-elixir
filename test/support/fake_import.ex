defmodule FraytElixir.Test.FakeImport do
  def fetch(_), do: {:ok, %{body: "test", status_code: 200}}
end
