defmodule FraytElixir.HTTPoser do
  def get(url) when is_bitstring(url), do: url |> to_charlist() |> get()

  def get(url) do
    with {:ok, resp} <- :httpc.request(:get, {url, []}, [], body_format: :binary),
         {{_, code, 'OK'}, headers, binary} <- resp do
      {:ok, %{body: binary, status_code: code, headers: headers}}
    else
      {:error, reason} ->
        {:error, reason}

      {{_, code, _reason}, headers, body} ->
        {:ok, %{status_code: code, body: body, headers: headers}}
    end
  end
end
