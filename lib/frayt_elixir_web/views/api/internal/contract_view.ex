defmodule FraytElixirWeb.API.Internal.ContractView do
  use FraytElixirWeb, :view

  def render("contract.json", %{contract: contract}) do
    %{id: contract.id, name: contract.name, contract_key: contract.contract_key}
  end
end
