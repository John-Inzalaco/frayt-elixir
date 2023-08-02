defmodule FraytElixirWeb.ErrorView do
  use FraytElixirWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("error_code.json", %{message: message} = params) do
    code = Map.get(params, :code, "")

    %{
      message: message,
      code: code
    }
  end

  def render("error_message.json", message: message) do
    %{error: message}
  end

  def render("error_changeset.json", %{changeset: changeset}) do
    %{
      message:
        changeset
        |> translate_errors()
        |> Enum.map_join(", ", fn {k, v} -> "#{humanize(k)} #{v}" end)
    }
  end

  def render("stripe_error.json", %{error: %Stripe.Error{message: message, code: code}}) do
    %{
      message: message,
      code: code
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end
end
