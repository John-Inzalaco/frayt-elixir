defmodule FraytElixir.Import do
  require Logger

  alias FraytElixir.Convert

  def convert_to_map_list([{:ok, header_row} | data_tuples]) do
    Enum.map(data_tuples, fn {_, data} ->
      header_row |> Enum.zip(data) |> Enum.into(%{})
    end)
  end

  def save_error(%{field: field, error: error, data: data}) do
    {:ok, file} = File.open("./migration/import_errors.csv", [:write, :utf8])

    [[field, error, inspect(data)]]
    |> CSV.encode()
    |> Enum.each(&IO.write(file, &1))

    File.close(file)
    nil
  rescue
    _ ->
      {:ok, file} = File.open("./migration/import_errors.csv", [:write, :utf8])

      [[field, error, "could not save data"]]
      |> CSV.encode()
      |> Enum.each(&IO.write(file, &1))

      File.close(file)
      nil
  end

  defp cleanup_string(value), do: String.replace(value, ~r/[^\-\.\d]+/, "")

  def convert_to_integer(value) do
    value
    |> cleanup_string()
    |> Convert.to_float(0)
    |> round()
  end
end
