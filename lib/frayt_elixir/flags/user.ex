defmodule FraytElixir.Flags.User do
  defimpl FunWithFlags.Actor, for: FraytElixir.Accounts.User do
    def id(%{id: id}) do
      "user:#{id}"
    end
  end
end
