defprotocol FraytElixir.RecordSearch do
  @type record_filters :: %{
          required(:query) => String.t() | nil,
          any() => any()
        }
  @doc """
  Defines a protocol for the FraytElxiir.RecordSearchSelect to be able to search and list results of a given struct.
  ---------------

  Returns a list of records filtered by the search query and any other filters, along with the total number of pages
  """
  @spec list_records(record :: struct(), filters :: record_filters()) :: {list(), integer()}
  def list_records(record, filters)

  @doc """
  Returns a record found by id
  """
  @spec get_record(record :: struct()) :: struct() | nil
  def get_record(record)

  @doc """
  Returns a string label for a given record
  """
  @spec display_record(record :: struct()) :: String.t() | Phoenix.HTML.Safe.t()
  def display_record(record)
end
