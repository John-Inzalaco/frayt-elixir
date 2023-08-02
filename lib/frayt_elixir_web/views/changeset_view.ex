defmodule FraytElixirWeb.ChangesetView do
  use FraytElixirWeb, :view

  import FraytElixirWeb.DisplayFunctions, only: [translate_errors: 1, humanize_errors: 1]

  def render("error.json", %{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: translate_errors(changeset)}
  end

  def render("error_message.json", %{changeset: changeset, code: :bringg_error}) do
    %{
      success: false,
      error_message: humanize_errors(changeset)
    }
  end

  def render("error_message.json", %{changeset: changeset, code: code}) do
    %{
      message: humanize_errors(changeset),
      code: code
    }
  end

  def render("error_message.json", %{changeset: changeset}),
    do: render("error_message.json", %{changeset: changeset, code: "invalid_attributes"})
end
