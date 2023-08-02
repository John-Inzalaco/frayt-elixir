defmodule FraytElixir.ContractsTest do
  use FraytElixir.DataCase

  alias FraytElixir.Contracts

  describe "contracts" do
    alias FraytElixir.Contracts.Contract
    alias FraytElixir.Accounts.Company

    test "list_contracts/1 returns all contracts" do
      %{id: contract_id} = insert(:contract)

      assert {contracts, 1} = Contracts.list_contracts(%{})

      assert [
               %Contract{
                 id: ^contract_id,
                 company: %Company{}
               }
             ] = sort_by_list(contracts, [contract_id], & &1.id)
    end

    test "list_contracts/1 filters by company_id" do
      company = insert(:company)

      insert(:contract)
      %{id: contract_id} = insert(:contract, company: company)

      assert {contracts, 1} = Contracts.list_contracts(%{company_id: company.id})

      assert [
               %Contract{id: ^contract_id}
             ] = sort_by_list(contracts, [contract_id], & &1.id)
    end

    test "list_contracts/1 filters by search query" do
      %{id: contract1_id} = insert(:contract, name: "Atd", contract_key: "nothin")
      %{id: contract2_id} = insert(:contract, name: "Nothin", contract_key: "atd")
      insert(:contract, name: "not that", contract_key: "balloon")

      assert {contracts, 1} = Contracts.list_contracts(%{query: "atd"})

      assert [
               %Contract{id: ^contract1_id},
               %Contract{id: ^contract2_id}
             ] = sort_by_list(contracts, [contract1_id, contract2_id], & &1.id)
    end

    test "get_contract/1 returns contract" do
      %{id: contract_id} = insert(:contract)

      assert %Contract{id: ^contract_id, company: %Company{}} =
               Contracts.get_contract(contract_id)
    end

    test "get_contract/1 returns nil for no match" do
      match = insert(:match)
      refute Contracts.get_contract(match.id)
    end

    test "get_contract/1 returns nil for invalid id" do
      refute Contracts.get_contract("junk")
    end

    test "get_contract/1 returns nil for nil" do
      refute Contracts.get_contract(nil)
    end

    test "get_company_contract_by_key/1 return contract" do
      company = insert(:company)
      %{id: contract_id} = insert(:contract, contract_key: "atd", company: company)

      assert %Contract{id: ^contract_id} =
               Contracts.get_company_contract_by_key("atd", company.id)
    end

    test "get_company_contract_by_key/1 returns nil for partial match" do
      company = insert(:company)
      insert(:contract, contract_key: "somethin", company: company)
      refute Contracts.get_company_contract_by_key("somethin", "nothin")
      refute Contracts.get_company_contract_by_key("nothin", company.id)
    end

    test "get_company_contract_by_key/1 returns nil for nil" do
      refute Contracts.get_company_contract_by_key(nil, "id")
      refute Contracts.get_company_contract_by_key("key", nil)
    end

    test "get_company_contract/1 return contract" do
      company = insert(:company)
      %{id: contract_id} = insert(:contract, company: company)

      assert %Contract{id: ^contract_id} = Contracts.get_company_contract(contract_id, company.id)
    end

    test "get_company_contract/1 returns nil for partial match" do
      company = insert(:company)
      contract = insert(:contract, contract_key: "somethin", company: company)
      refute Contracts.get_company_contract(contract.id, "nothin")
      refute Contracts.get_company_contract("nothin", company.id)
    end

    test "get_company_contract/1 returns nil for nil" do
      refute Contracts.get_company_contract(nil, "id")
      refute Contracts.get_company_contract("key", nil)
    end

    test "update_contract/2 with valid data updates the contract" do
      contract = insert(:contract)

      assert {:ok, %Contract{name: "new name"}} =
               Contracts.update_contract(contract, %{name: "new name"})
    end

    test "update_contract/2 with invalid data returns error changeset" do
      contract = insert(:contract)

      assert {:error, %Ecto.Changeset{}} = Contracts.update_contract(contract, %{name: nil})
    end

    test "change_contract/2 returns changeset" do
      %{id: company_id} = insert(:company)

      assert %Ecto.Changeset{
               changes: %{company_id: ^company_id, contract_key: "atd", name: "ATD"},
               valid?: true
             } =
               Contracts.change_contract(%Contract{}, %{
                 company_id: company_id,
                 contract_key: "atd",
                 name: "ATD"
               })
    end

    test "change_contract/1 with invalid pricing contract returns error changeset" do
      %{id: company_id} = insert(:company)

      assert %Ecto.Changeset{valid?: false, errors: [pricing_contract: _]} =
               Contracts.change_contract(%Contract{}, %{
                 company_id: company_id,
                 pricing_contract: :nonsense,
                 contract_key: "atd",
                 name: "ATD"
               })
    end

    test "change_contract/1 succeeds with duplicate contract key from other company" do
      insert(:contract, contract_key: "atd")
      %{id: company_id} = insert(:company)

      assert {:ok,
              %Contract{
                company_id: ^company_id,
                contract_key: "atd"
              }} =
               %Contract{}
               |> Contracts.change_contract(%{
                 company_id: company_id,
                 contract_key: "atd",
                 name: "ATD"
               })
               |> Repo.insert()

      #  since this is a unique_constraint, we need to attempt an insert
    end

    test "change_contract/1 with fails on duplicate contract for company" do
      %{id: company_id} = company = insert(:company)
      insert(:contract, contract_key: "atd", company: company)

      assert {:error, %Ecto.Changeset{}} =
               %Contract{}
               |> Contracts.change_contract(%{
                 company_id: company_id,
                 contract_key: "atd",
                 name: "ATD"
               })
               |> Repo.insert()

      #  since this is a unique_constraint, we need to attempt an insert
    end

    test "change_contract_cancellation/2 returns changeset" do
      contract = insert(:contract)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{
                 allowed_cancellation_states: [:picked_up, :completed],
                 cancellation_pay_rules: [
                   %Ecto.Changeset{
                     changes: %{
                       in_states: [:en_route_to_pickup],
                       driver_percent: 0.5,
                       cancellation_percent: 0.7,
                       max_matches: 1,
                       time_on_match: 3600
                     }
                   }
                 ]
               }
             } =
               Contracts.change_contract_cancellation(contract, %{
                 allowed_cancellation_states: [:picked_up, :completed],
                 cancellation_pay_rules: [
                   %{
                     in_states: [:en_route_to_pickup],
                     driver_percent: 0.5,
                     cancellation_percent: 0.7,
                     max_matches: 1,
                     time_on_match: 60 * 60
                   }
                 ]
               })
    end

    test "change_contract_cancellation/2 returns error for missing data" do
      contract = insert(:contract)

      assert %Ecto.Changeset{
               valid?: false,
               errors: [allowed_cancellation_states: {_, [validation: :required]}],
               changes: %{cancellation_pay_rules: [cpr_changeset]}
             } =
               Contracts.change_contract_cancellation(contract, %{
                 allowed_cancellation_states: nil,
                 cancellation_pay_rules: [
                   %{
                     in_states: nil,
                     max_matches: nil,
                     time_on_match: nil,
                     driver_percent: nil,
                     cancellation_percent: nil
                   }
                 ]
               })

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 driver_percent: {_, [validation: :required]},
                 cancellation_percent: {_, [validation: :required]},
                 in_states: {_, [validation: :required]}
               ]
             } = cpr_changeset
    end

    test "change_contract_cancellation/2 returns errors invalid data" do
      contract = insert(:contract)

      assert %Ecto.Changeset{
               valid?: false,
               errors: [allowed_cancellation_states: {"has an invalid entry", _}],
               changes: %{cancellation_pay_rules: [cpr_changeset]}
             } =
               Contracts.change_contract_cancellation(contract, %{
                 allowed_cancellation_states: [:charged],
                 cancellation_pay_rules: [
                   %{
                     restrict_states: true,
                     in_states: [],
                     max_matches: nil,
                     time_on_match: nil,
                     driver_percent: -0.4,
                     cancellation_percent: 1.6
                   }
                 ]
               })

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 driver_percent: {"must be between 0% and 100%", _},
                 cancellation_percent: {"must be between 0% and 100%", _},
                 in_states: {_, [count: 1, validation: :assoc_length, kind: :min]}
               ]
             } = cpr_changeset
    end
  end

  describe "get_match_cancellation_pay_rule/2" do
    alias FraytElixir.Contracts.CancellationPayRule

    defp build_sla_match(end_time, address, attrs \\ []),
      do:
        insert(
          :match,
          [
            slas: [
              insert(:match_sla,
                type: :pickup,
                end_time: end_time,
                driver: attrs[:driver] || insert(:driver)
              )
            ],
            origin_address: insert(:address, formatted_address: address)
          ] ++ attrs
        )

    test "returns nil for no contract" do
      match = insert(:match, contract: nil)
      refute Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns nil for no rules" do
      match = insert(:match, contract: insert(:contract, cancellation_pay_rules: []))
      refute Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns nil for no matching rules" do
      match =
        insert(:match,
          contract:
            insert(:contract,
              cancellation_pay_rules: [
                build(:cancellation_pay_rule, in_states: [:completed], restrict_states: true)
              ]
            )
        )

      refute Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns rule that matches restricted states" do
      rule =
        build(:cancellation_pay_rule,
          in_states: [:pending, :picked_up],
          restrict_states: true
        )

      match =
        insert(:match,
          state: :pending,
          contract: insert(:contract, cancellation_pay_rules: [rule])
        )

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns rule that matches restricted states using previous state when canceled" do
      contract =
        insert(:contract,
          cancellation_pay_rules: [
            build(:cancellation_pay_rule,
              in_states: [:pending, :picked_up],
              restrict_states: true
            )
          ]
        )

      canceled_match =
        insert(:match,
          state: :canceled,
          contract: contract,
          state_transitions: [insert(:match_state_transition, from: :picked_up, to: :canceled)]
        )

      admin_canceled_match =
        insert(:match,
          state: :admin_canceled,
          contract: contract,
          state_transitions: [
            insert(:match_state_transition, from: :picked_up, to: :admin_canceled)
          ]
        )

      other_match =
        insert(:match,
          state: :canceled,
          contract: contract,
          state_transitions: [insert(:match_state_transition, from: :completed, to: :canceled)]
        )

      transitionless_match =
        insert(:match,
          state: :canceled,
          contract: contract,
          state_transitions: [insert(:match_state_transition, from: :completed, to: :charged)]
        )

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(canceled_match)

      assert %CancellationPayRule{} =
               Contracts.get_match_cancellation_pay_rule(admin_canceled_match)

      refute Contracts.get_match_cancellation_pay_rule(other_match)
      refute Contracts.get_match_cancellation_pay_rule(transitionless_match)
    end

    test "returns rule that matches time on match" do
      rule = build(:cancellation_pay_rule, time_on_match: 15)

      match =
        insert(:match,
          contract: insert(:contract, cancellation_pay_rules: [rule]),
          state_transitions: [
            insert(:match_state_transition,
              from: :assigning_driver,
              to: :accepted,
              inserted_at: ~N[2020-01-01 00:00:00]
            ),
            insert(:match_state_transition,
              from: :assigning_driver,
              to: :accepted,
              inserted_at: ~N[2020-02-01 00:00:00]
            )
          ],
          scheduled: false
        )

      refute Contracts.get_match_cancellation_pay_rule(
               match,
               build(:match_state_transition, to: :canceled, inserted_at: ~N[2020-01-01 00:15:00])
             )

      assert %CancellationPayRule{} =
               Contracts.get_match_cancellation_pay_rule(
                 match,
                 build(:match_state_transition,
                   to: :canceled,
                   inserted_at: ~N[2020-02-01 00:15:00]
                 )
               )
    end

    test "returns rule that matches max driver matches in 30 min at same pickup" do
      rule = build(:cancellation_pay_rule, max_matches: 2)
      contract = insert(:contract, cancellation_pay_rules: [rule])

      driver = insert(:driver)

      match1 =
        build_sla_match(~N[2020-01-01 12:00:00], "this address",
          contract: contract,
          driver: driver
        )

      match2 =
        build_sla_match(~N[2020-02-01 12:00:00], "this address",
          contract: contract,
          driver: driver
        )

      build_sla_match(~N[2020-01-01 12:00:00], "this address", driver: driver)
      build_sla_match(~N[2020-01-01 12:30:00], "this address", driver: driver)
      build_sla_match(~N[2020-01-01 11:30:00], "this address", driver: driver)

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(match1)

      refute Contracts.get_match_cancellation_pay_rule(match2)
    end

    test "max matches ignores different addresses and times further out than 30 min and other drivers" do
      rule = build(:cancellation_pay_rule, max_matches: 0)
      contract = insert(:contract, cancellation_pay_rules: [rule])

      driver = insert(:driver)

      match =
        build_sla_match(~N[2020-01-01 12:00:00], "this address",
          contract: contract,
          driver: driver
        )

      build_sla_match(~N[2020-02-01 12:00:00], "this address", driver: driver)
      build_sla_match(~N[2020-01-01 12:00:00], "other address", driver: driver)
      build_sla_match(~N[2020-01-01 12:00:00], "this address")

      refute Contracts.get_match_cancellation_pay_rule(match)
    end

    test "prioritizes rule by order" do
      contract =
        insert(:contract,
          cancellation_pay_rules: [
            build(:cancellation_pay_rule, max_matches: 0, driver_percent: 0.5),
            build(:cancellation_pay_rule, max_matches: 0, driver_percent: 0.75)
          ]
        )

      driver = insert(:driver)

      match =
        build_sla_match(~N[2020-01-01 12:00:00], "this address",
          contract: contract,
          driver: driver
        )

      build_sla_match(~N[2020-01-01 12:00:00], "this address", driver: driver)

      assert %CancellationPayRule{driver_percent: 0.5} =
               Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns rule that matches vehicle_class" do
      rule = build(:cancellation_pay_rule, vehicle_class: [:car, :box_truck])

      match =
        insert(:match,
          vehicle_class: 1,
          contract: insert(:contract, cancellation_pay_rules: [rule])
        )

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns nil for no matching vehicle_class rules" do
      rule = build(:cancellation_pay_rule, vehicle_class: [:car])

      match =
        insert(:match,
          vehicle_class: 4,
          contract: insert(:contract, cancellation_pay_rules: [rule])
        )

      refute Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns rule that matches canceled_by for :shipper" do
      rule = build(:cancellation_pay_rule, canceled_by: [:shipper])

      match =
        insert(:match,
          contract: insert(:contract, cancellation_pay_rules: [rule]),
          state_transitions: [
            insert(:match_state_transition,
              from: :accepted,
              to: :canceled,
              inserted_at: ~N[2020-02-01 00:00:00]
            )
          ]
        )

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns rule that matches canceled_by for :admin" do
      rule = build(:cancellation_pay_rule, canceled_by: [:admin])

      match =
        insert(:match,
          contract: insert(:contract, cancellation_pay_rules: [rule]),
          state_transitions: [
            insert(:match_state_transition,
              from: :accepted,
              to: :admin_canceled,
              inserted_at: ~N[2020-02-01 00:00:00]
            )
          ]
        )

      assert %CancellationPayRule{} = Contracts.get_match_cancellation_pay_rule(match)
    end

    test "returns nil for no matching canceled_by rules" do
      rule = build(:cancellation_pay_rule, canceled_by: [:admin])

      match =
        insert(:match,
          contract: insert(:contract, cancellation_pay_rules: [rule]),
          state_transitions: [
            insert(:match_state_transition,
              from: :accepted,
              to: :canceled,
              inserted_at: ~N[2020-02-01 00:00:00]
            )
          ]
        )

      refute Contracts.get_match_cancellation_pay_rule(match)
    end
  end
end
