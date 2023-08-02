defmodule FraytElixir.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import FraytElixir.Validators
      import FraytElixir.ChangesetHelpers
      import Ecto.Changeset
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
