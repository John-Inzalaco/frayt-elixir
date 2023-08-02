defmodule FraytElixir.Repo.Migrations.AddAndMoveServicesToMatches do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

    alter table(:matches) do
      add :unload_method, :string
      add :has_pallet_jack, :boolean
      add :has_load_unload, :boolean
    end

    execute &up_data/0, &down_data/0

    alter table(:matches) do
      remove :lift_gate, :boolean
      remove :lift_gate_price, :integer
      remove :total_base_price, :integer
      remove :driver_base_price, :integer
      remove :total_load_fee_price, :integer
      remove :driver_load_fee_price, :integer
      remove :toll_fee_price, :integer
      remove :route_fee_price, :integer
      remove :total_tip_price, :integer
    end
  end

  defp populate_pallet_jack do
    repo().query!(
      """
      update matches
      set has_pallet_jack = false;
      """,
      [],
      log: :info
    )
  end

  defp migrate_has_load_unload do
    repo().query!(
      """
      update matches
      set has_load_unload = stops.have_load
      from (
        select ms.match_id, coalesce(bool_or(ms.has_load_fee), false) as have_load
        from match_stops as ms
        where ms.match_id is not null
        group by ms.match_id
      ) as stops
      where matches.id = stops.match_id;
      """,
      [],
      log: :info
    )
  end

  defp up_data do
    populate_pallet_jack()
    migrate_has_load_unload()
    migrate_to_match_fee("base_fee", "total_base_price", "driver_base_price")
    migrate_to_match_fee("load_fee", "total_load_fee_price", "driver_load_fee_price")
    migrate_to_match_fee("route_surcharge", "route_fee_price")
    migrate_to_match_fee("driver_tip", "total_tip_price", "total_tip_price")
    migrate_to_match_fee("toll_fees", "toll_fee_price", "toll_fee_price")
  end

  defp down_data do
    migrate_from_match_fee("base_fee", "total_base_price", "driver_base_price")
    migrate_from_match_fee("load_fee", "total_load_fee_price", "driver_load_fee_price")
    migrate_from_match_fee("route_surcharge", "route_fee_price")
    migrate_from_match_fee("driver_tip", "total_tip_price")
    migrate_from_match_fee("toll_fees", "toll_fee_price")
  end

  defp migrate_from_match_fee(type, amount_col, driver_amount_col \\ nil) do
    set =
      build_set([
        {amount_col, "match_fees.amount"},
        {driver_amount_col, "match_fees.driver_amount"}
      ])

    repo().query!(
      """
      update matches
      set #{set}
      from match_fees
      where match_fees.match_id = matches.id and match_fees.type = $1
      """,
      [type],
      log: :info
    )

    if amount_col do
      repo().query!("update matches set #{amount_col} = 0 where #{amount_col} is null", [],
        log: :info
      )
    end

    if driver_amount_col do
      repo().query!(
        "update matches set #{driver_amount_col} = 0 where #{driver_amount_col} is null",
        [],
        log: :info
      )
    end

    repo().query!("delete from match_fees where match_fees.type = $1", [type], log: :info)
  end

  defp migrate_to_match_fee(type, amount_col, driver_amount_col \\ nil) do
    amount = amount_or_0(amount_col)
    driver_amount = amount_or_0(driver_amount_col)

    conds = build_where([{amount_col, "> 0"}, {driver_amount_col, "> 0"}])

    repo().query!(
      """
      insert into match_fees (id, match_id, type, amount, driver_amount, inserted_at, updated_at)
      select gen_random_uuid(), m.id, $1, #{amount}, #{driver_amount}, NOW(), NOW() from matches as m
      where #{conds}
      """,
      [type],
      log: :info
    )
  end

  defp amount_or_0(nil), do: 0
  defp amount_or_0(column), do: "CASE WHEN m.#{column} is null then 0 else m.#{column} end"

  defp build_set(sets),
    do:
      sets
      |> Enum.map(&maybe_set(elem(&1, 0), elem(&1, 1)))
      |> Enum.filter(& &1)
      |> Enum.join(", ")

  defp build_where(conds),
    do:
      conds
      |> Enum.map(&maybe_where(elem(&1, 0), elem(&1, 1)))
      |> Enum.filter(& &1)
      |> Enum.join(" or ")

  defp maybe_set(nil, _), do: nil
  defp maybe_set(column, value), do: "#{column} = #{value}"

  defp maybe_where(nil, _), do: nil
  defp maybe_where(column, condition), do: "#{column} #{condition}"
end
