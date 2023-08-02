defmodule FraytElixir.Helpers.TablePartitioning do
  import Ecto.Migration

  def create_partition(table, start_date), do: create_partition(table, start_date, [])

  def create_partition(table, start_date, opts) when is_list(opts) do
    end_date = next_month(start_date)

    create_partition(table, start_date, end_date, opts)
  end

  def create_partition(table, start_date, end_date, opts \\ []) do
    partition_name = partition_table_name(table, start_date)
    partition_target = partition_range(start_date, end_date)

    create_partition_sql(table, partition_name, partition_target, opts)
  end

  def create_default_partition(table, opts \\ []) do
    partition_name = "#{table}_default"
    partition_target = "DEFAULT"

    create_partition_sql(table, partition_name, partition_target, opts)
  end

  defp create_partition_sql(table, partition_name, partition_target, opts) do
    if_not_exists = if opts[:if_not_exists], do: "IF NOT EXISTS "

    repo().query!("""
    CREATE TABLE #{if_not_exists}#{partition_name}
    PARTITION OF #{table} #{partition_target}
    """)
  end

  def drop_partition(table, start_date, opts \\ []) do
    partition_name = partition_table_name(table, start_date)

    drop_partition_sql(partition_name, opts)
  end

  def drop_default_partition(table, opts \\ []) do
    partition_name = "#{table}_default"

    drop_partition_sql(partition_name, opts)
  end

  defp drop_partition_sql(partition_name, opts) do
    if_exists = if opts[:if_exists], do: "IF EXISTS "
    repo().query!("DROP TABLE #{if_exists}#{partition_name}")
  end

  def create_monthly_partitions(table, start_date, end_date) do
    iterate_months(start_date, end_date, fn this_date ->
      create_partition(table, this_date)
    end)
  end

  def drop_monthly_partitions(table, start_date, end_date) do
    iterate_months(start_date, end_date, fn this_date ->
      drop_partition(table, this_date, if_exists: true)
    end)
  end

  def drop_all_partitions(table) do
    start_date = get_start_date(table)
    end_date = get_end_date(table)

    drop_monthly_partitions(table, start_date, end_date)
  end

  def migrate_to_partition(to_table, opts),
    do: migrate_between_partition(to_table, :up, opts ++ [reverse: false])

  def migrate_from_partition(from_table, [{:to, to_table} | opts]),
    do: migrate_between_partition(to_table, :down, [from: from_table, reverse: true] ++ opts)

  defp migrate_between_partition(to_table, direction, [{:from, from_table} | opts]) do
    start_date = get_start_date(from_table)
    end_date = get_end_date(from_table)

    case direction do
      :up ->
        create_monthly_partitions(to_table, start_date, end_date)
        copy_data_to_table(from_table, to_table, opts)

      :down ->
        copy_data_to_table(from_table, to_table, opts)
    end
  end

  defp copy_data_to_table(from_table, to_table, opts) do
    reverse? = Keyword.fetch!(opts, :reverse)
    columns = Keyword.fetch!(opts, :columns)
    from_table = Atom.to_string(from_table)
    to_table = Atom.to_string(to_table)

    {from_columns, to_columns} =
      Enum.reduce(columns, {"", ""}, fn column, {from_sql, to_sql} ->
        {from, to} =
          case column do
            {from, to} when not reverse? -> {from, to}
            {to, from} when reverse? -> {from, to}
            col when is_atom(col) -> {col, col}
          end

        {append_column(from_sql, from), append_column(to_sql, to)}
      end)

    repo().query!("""
    INSERT INTO #{to_table} (#{to_columns})
    SELECT #{from_columns} FROM #{from_table}
    """)
  end

  defp append_column("", col), do: ~s("#{col}")
  defp append_column(acc, col), do: ~s(#{acc},"#{col}")

  defp iterate_months(start_date, end_date, callback) do
    if start_date && end_date do
      months = end_date.month - start_date.month + (end_date.year - start_date.year) * 12

      Enum.reduce(0..months, start_date, fn _index, this_date ->
        callback.(this_date)

        next_month(this_date)
      end)
    end
  end

  defp get_start_date(table), do: get_edge_date(table, :asc)
  defp get_end_date(table), do: get_edge_date(table, :desc)
  defp next_month(date), do: Timex.shift(date, months: 1)

  defp get_edge_date(table, order) when order in [:asc, :desc] do
    results =
      repo().query!("SELECT inserted_at FROM #{table} ORDER BY inserted_at #{order} LIMIT 1")

    case results do
      %{rows: [[%NaiveDateTime{} = inserted_at]]} -> Date.beginning_of_month(inserted_at)
      _ -> nil
    end
  end

  def attach_partition(table, partition_table, start_date, end_date) do
    execute("""
    ALTER TABLE #{table}
    ATTACH PARTITION #{partition_table} #{partition_range(start_date, end_date)}
    """)
  end

  defp partition_range(start_date, end_date) do
    """
    FOR VALUES
    FROM ('#{start_date}')
    TO ('#{end_date}')
    """
  end

  defp partition_table_name(table, start_date) do
    month =
      start_date.month
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "#{table}_p#{start_date.year}_#{month}"
  end
end
