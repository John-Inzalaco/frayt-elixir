defmodule FraytElixir.Helpers.NumberConversion do
  alias FraytElixir.Convert

  def dollars_to_cents(dollars) do
    amount = Convert.to_float(dollars) || 0
    ceil(amount * 100)
  end
end
