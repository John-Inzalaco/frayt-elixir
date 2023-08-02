defmodule FraytElixir.MatchFilterTest do
  use FraytElixir.DataCase

  alias FraytElixir.Repo
  alias FraytElixir.Shipment.Match

  import FraytElixir.Factory

  describe "filter_by_transaction_type/2" do
    test "with :failed, returns matches where latest capture or transfer charge failed" do
      successful_match = insert(:match)
      %{id: failed_transfer_match_id} = failed_transfer_match = insert(:match)
      %{id: failed_capture_match_id} = failed_capture_match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "capture",
        amount: 300,
        match: successful_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_transfer_match
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: failed_transfer_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "transfer",
        amount: 300,
        match: successful_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_capture_match
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: failed_capture_match
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "transfer",
        amount: 300,
        match: failed_capture_match
      )

      expected_transactions = [failed_transfer_match_id, failed_capture_match_id] |> Enum.sort()

      assert ^expected_transactions =
               Match
               |> Match.filter_by_transaction_type(:failed)
               |> Repo.all()
               |> Enum.map(& &1.id)
               |> Enum.sort()
    end

    test "with :captures, returns matches where latest capture charge failed" do
      successful_match = insert(:match)
      %{id: failed_match_id} = failed_match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "capture",
        amount: 300,
        match: successful_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_match
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: failed_match
      )

      assert [%{id: ^failed_match_id}] =
               Match
               |> Match.filter_by_transaction_type(:captures)
               |> Repo.all()
    end

    test "with :captures, does not return match if capture charge failed then another capture succeeded later" do
      now = DateTime.utc_now()
      failed_match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: failed_match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "capture",
        amount: 300,
        match: failed_match,
        inserted_at: DateTime.add(now, 1 * 600)
      )

      assert [] =
               Match
               |> Match.filter_by_transaction_type(:captures)
               |> Repo.all()
    end

    test "with :transfers, returns matches where latest transfer charge failed" do
      successful_match = insert(:match)
      %{id: failed_match_id} = failed_match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "transfer",
        amount: 300,
        match: successful_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_match
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "capture",
        amount: 300,
        match: failed_match
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "transfer",
        amount: 300,
        match: failed_match
      )

      assert [%{id: ^failed_match_id}] =
               Match
               |> Match.filter_by_transaction_type(:transfers)
               |> Repo.all()
    end

    test "with :transfers, does not return match if transfer pay failed then another transfer succeeded later" do
      now = DateTime.utc_now()
      failed_match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: failed_match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: failed_match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "transfer",
        amount: 300,
        match: failed_match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "success",
        transaction_type: "transfer",
        amount: 300,
        match: failed_match,
        inserted_at: DateTime.add(now, 1 * 600)
      )

      assert [] =
               Match
               |> Match.filter_by_transaction_type(:transfers)
               |> Repo.all()
    end

    test "with :all, returns all matches" do
      now = DateTime.utc_now()
      insert(:match)
      match = insert(:match)

      insert(:payment_transaction,
        status: "success",
        transaction_type: "authorize",
        amount: 300,
        match: match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "capture",
        amount: 300,
        match: match,
        inserted_at: now
      )

      insert(:payment_transaction,
        status: "error",
        transaction_type: "transfer",
        amount: 300,
        match: match,
        inserted_at: now
      )

      results =
        Match
        |> Match.filter_by_transaction_type(:all)
        |> Repo.all()

      assert Enum.count(results) == 2
    end
  end
end
