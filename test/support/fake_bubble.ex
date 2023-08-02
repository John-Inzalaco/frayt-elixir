defmodule FraytElixir.Test.FakeBubble do
  def authenticate(_, "garbage"), do: {:error, :invalid_credentials}
  def authenticate(_, _), do: {:ok, "great it worked good job!"}
end
