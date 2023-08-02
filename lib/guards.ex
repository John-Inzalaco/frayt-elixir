defmodule FraytElixir.Guards do
  defguard is_empty(value) when is_nil(value) or value == ""
end
