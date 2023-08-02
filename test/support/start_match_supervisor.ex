defmodule FraytElixir.Test.StartMatchSupervisor do
  alias FraytElixir.MatchSupervisor

  use ExUnit.CaseTemplate

  def start_match_supervisor(_) do
    {:ok, _pid} = start_supervised(MatchSupervisor)
    :ok
  end
end
