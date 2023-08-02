defmodule FraytElixir.Test.FakeApiAccount do
  import Ecto.Changeset

  def generate_client_and_secret(%Ecto.Changeset{} = changeset) do
    changeset
    |> put_change(:client_id, "1234567890")
    |> put_change(:secret, "1234567890")
  end
end
