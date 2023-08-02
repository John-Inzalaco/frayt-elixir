defmodule FraytElixirWeb.Admin.ContractsView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Contracts.{CancellationPayRule, CancellationCode, MarketConfig}
  alias FraytElixir.SLAs.{ContractSLA, SLADurationType, SLAType}
  alias FraytElixir.CustomContracts
  alias FraytElixir.Accounts.Company
  alias FraytElixirWeb.AdminAlerts
  alias FraytElixir.Shipment.MatchState
  alias FraytElixir.Type.EnumHelper
  alias FraytElixir.Vehicle.VehicleType
  alias FraytElixir.Accounts.UserType

  alias FraytElixirWeb.DataTable.Helpers, as: Table

  def display_rules(%CancellationPayRule{} = rule) do
    rules =
      []
      |> build_rule(
        rule.restrict_states,
        "the Match's state is " <> Enum.map_join(rule.in_states, " or ", &MatchState.name(&1))
      )
      |> build_rule(
        rule.max_matches,
        "the driver has no more than #{rule.max_matches} other Match(es) at the same pickup location"
      )
      |> build_rule(
        rule.time_on_match,
        "the driver has been on a Match for at least #{rule.time_on_match} minute(s)"
      )
      |> build_rule(
        rule.vehicle_class,
        "the vehicle class is a " <>
          Enum.map_join(rule.vehicle_class, " or ", &VehicleType.name(&1))
      )
      |> build_rule(
        rule.canceled_by,
        "the user is a " <>
          Enum.map_join(rule.canceled_by, " or ", &UserType.name(&1))
      )

    if length(rules) > 0 do
      "When " <> Enum.join(rules, ", and ")
    else
      "When none of the above rules are met"
    end
  end

  def build_rule(messages, show?, _message) when is_nil(show?) or show? == false, do: messages

  def build_rule(messages, _show?, message),
    do: [message | messages]

  def display_error(%{valid?: false, errors: [duration: {msg, _}]}), do: msg

  def display_error(_), do: nil

  def inputs_for_slas(form) do
    inputs = inputs_for(form, :slas)

    build_slas(fn type ->
      Enum.find(inputs, fn i ->
        input_value(i, :type) in [type, to_string(type)]
      end)
    end)
  end

  def list_slas(contract) do
    build_slas(fn type ->
      Enum.find(contract.slas, &(&1.type == type))
    end)
  end

  defp build_slas(mapper) do
    SLAType.all_types()
    |> Enum.sort_by(&prioritize_slas(&1))
    |> Enum.map(&{&1, mapper.(&1)})
  end

  defp prioritize_slas(:acceptance), do: 0
  defp prioritize_slas(:pickup), do: 1
  defp prioritize_slas(:delivery), do: 2

  defp duration_type_value(form) do
    value = input_value(form, :duration_type)

    case value do
      "" -> nil
      nil -> nil
      value when is_atom(value) -> Atom.to_string(value)
      value -> value
    end
  end

  defp duration_label(type, duration_type) do
    if duration_type == "duration_before_time" do
      "#{humanize(type)} Duration Before Time (minutes)"
    else
      "#{humanize(type)} (minutes)"
    end
  end
end
