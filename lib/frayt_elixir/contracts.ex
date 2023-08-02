defmodule FraytElixir.Contracts do
  @moduledoc """
  The Contracts context.
  """
  alias FraytElixir.PaginationQueryHelpers

  import Ecto.Query, warn: false
  alias FraytElixir.Repo

  alias FraytElixir.Contracts.Contract
  alias FraytElixir.SLAs
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, MatchState, Address, MatchStateTransition}

  @default_contract_preloads [:company, :slas, :cancellation_codes, [market_configs: :market]]
  @cancelable_range MatchState.cancelable_range()
  @canceled_range MatchState.canceled_range()

  def get_contract(nil), do: nil

  def get_contract(id) do
    Repo.get(Contract, id) |> Repo.preload(@default_contract_preloads)
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_company_contract_by_key(key, company_id),
    do: get_company_contract_by(company_id, contract_key: key)

  def get_company_contract(id, company_id), do: get_company_contract_by(company_id, id: id)

  defp get_company_contract_by(company_id, clauses) do
    if not is_nil(company_id) and Enum.all?(clauses, &elem(&1, 1)) do
      Repo.get_by(Contract, [company_id: company_id] ++ clauses)
      |> Repo.preload(@default_contract_preloads)
    else
      nil
    end
  rescue
    Ecto.Query.CastError -> nil
  end

  def list_contracts(attrs, preload \\ @default_contract_preloads) do
    company_id = Map.get(attrs, :company_id)
    query = Map.get(attrs, :query)

    Contract
    |> Contract.filter_by_query(query)
    |> Contract.filter_by_company(company_id)
    |> PaginationQueryHelpers.list_record(attrs, preload)
  end

  def update_contract(%Contract{} = contract, attrs),
    do:
      contract
      |> change_contract(attrs)
      |> Repo.update()

  def change_contract(%Contract{} = contract, attrs \\ %{}),
    do: Contract.changeset(contract, attrs)

  def change_contract_cancellation(%Contract{} = contract, attrs \\ %{}),
    do: Contract.cancellation_changeset(contract, attrs)

  def change_contract_delivery_rules(%Contract{} = contract, attrs \\ %{}),
    do: Contract.delivery_rules_changeset(contract, attrs)

  def change_contract_slas(%Contract{} = contract, attrs \\ %{}),
    do: Contract.contract_sla_changeset(contract, attrs)

  def get_match_cancellation_codes(%Match{contract: nil}), do: nil
  def get_match_cancellation_codes(%Match{contract: %Contract{cancellation_codes: []}}), do: nil

  def get_match_cancellation_codes(%Match{
        contract: %Contract{cancellation_codes: cancellation_codes}
      }) do
    cancellation_codes
  end

  def change_market_configs(%Contract{} = contract, attrs \\ %{}) do
    Contract.contract_market_multiplier_changeset(contract, attrs)
  end

  def get_match_cancellation_pay_rule(%Match{} = match) do
    transition =
      case Shipment.match_canceled_transition(match, :desc) do
        nil ->
          %MatchStateTransition{
            from: match.state,
            to: :admin_canceled,
            inserted_at: NaiveDateTime.utc_now()
          }

        transition ->
          transition
      end

    get_match_cancellation_pay_rule(match, transition)
  end

  def get_match_cancellation_pay_rule(%Match{contract: nil}, _), do: nil

  def get_match_cancellation_pay_rule(%Match{contract: %Contract{cancellation_pay_rules: []}}, _),
    do: nil

  def get_match_cancellation_pay_rule(
        %Match{contract: %Contract{cancellation_pay_rules: rules}} = match,
        transition
      ) do
    Enum.find(rules, fn rule ->
      cancellation_state?(rule, match) and
        sufficient_time_on_match?(rule, match, transition.inserted_at) and
        below_max_matches?(rule, match) and allowed_vehicle_class?(rule, match) and
        cancelled_by_user_type?(rule, transition.to)
    end)
  end

  defp cancellation_state?(%{restrict_states: false}, _match), do: true

  defp cancellation_state?(%{in_states: in_states}, %Match{state: state} = match)
       when state in @canceled_range do
    case Shipment.find_transition(match, state, :desc) do
      nil -> false
      transition -> transition.from in in_states
    end
  end

  defp cancellation_state?(%{in_states: in_states}, %Match{state: state}),
    do: state in in_states

  defp sufficient_time_on_match?(%{time_on_match: nil}, _match, _cancel_time), do: true

  defp sufficient_time_on_match?(%{time_on_match: minutes}, match, cancel_time) do
    accepted_at = Shipment.match_transitioned_at(match, :accepted, :desc)

    NaiveDateTime.diff(cancel_time, accepted_at) >= minutes * 60
  end

  defp allowed_vehicle_class?(rule, match) do
    rule_vehicle_class = FraytElixir.Utils.vehicle_class_atom_to_integer(rule.vehicle_class)

    match.vehicle_class in rule_vehicle_class
  end

  defp cancelled_by_user_type?(%{canceled_by: []}, _state), do: true

  defp cancelled_by_user_type?(%{canceled_by: canceled_by}, state) do
    cond do
      :shipper in canceled_by and state == :canceled -> true
      :admin in canceled_by and state == :admin_canceled -> true
      true -> false
    end
  end

  # below_max_matches?/2 returns true when the driver has less than the maximum number of matches at
  # the same pickup with SLAs due within `max_diff` minutes of the canceled match's pickup SLA

  defp below_max_matches?(%{max_matches: nil}, _match), do: true

  defp below_max_matches?(
         %{max_matches: max},
         %Match{
           driver_id: driver_id,
           id: match_id,
           origin_address: %Address{formatted_address: address}
         } = match
       ) do
    max_diff = 30 * 60
    pickup_sla = SLAs.get_match_sla(match, :pickup, driver_id)

    if pickup_sla do
      pickup_time = pickup_sla.end_time
      earliest = NaiveDateTime.add(pickup_time, -max_diff, :second)
      latest = NaiveDateTime.add(pickup_time, max_diff, :second)

      query =
        from(m in Match,
          join: sla in assoc(m, :slas),
          on: sla.type == :pickup,
          join: oa in assoc(m, :origin_address),
          where:
            m.driver_id == ^driver_id and
              m.id != ^match_id and
              m.state in ^@cancelable_range and
              oa.formatted_address == ^address and
              not is_nil(sla.end_time) and
              sla.end_time >= ^earliest and
              sla.end_time <= ^latest,
          select: count(m.id)
        )

      count = Repo.one(query)

      count > max
    else
      true
    end
  end
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Contracts.Contract do
  alias FraytElixir.{Repo, Contracts}
  alias Contracts.Contract

  def display_record(c),
    do: {:safe, "#{c.name} <code>#{c.contract_key}</code>"}

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :name,
        order: :asc
      }
      |> Map.merge(filters)
      |> Contracts.list_contracts([])

  def get_record(%{id: id}), do: Repo.get(Contract, id)
end
