defmodule FraytElixir.Email do
  use Bamboo.Phoenix, view: FraytElixir.EmailView
  import Bamboo.Email
  alias FraytElixir.Shipment.Match
  alias FraytElixirWeb.Router.Helpers, as: Routes
  alias Premailex

  import FraytElixirWeb.DisplayFunctions,
    only: [full_name: 1]

  def match_status_email(
        %Match{} = match,
        metadata,
        %{
          to: to_email,
          subject: subject
        } = attrs
      ) do
    %{
      cc: cc_emails,
      bcc: bcc_emails,
      close: close
    } = Map.merge(%{cc: [], bcc: [], close: nil}, attrs)

    mst = Keyword.get(metadata, :mst)

    base_email()
    |> put_html_layout({FraytElixir.EmailView, "match_email.html"})
    |> to(to_email)
    |> cc(cc_emails)
    |> bcc(bcc_emails ++ [Application.get_env(:frayt_elixir, :notifications_email)])
    |> subject(subject)
    |> assign(:match, match)
    |> assign(:transition, mst)
    |> assign(:metadata, metadata |> Map.new())
    |> assign(:close, close)
    |> render("match_status.html")
    |> premail()
  end

  def invitation_email(%{email: email, password_reset_code: password_reset_code, name: name}) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "invitation.html"})
    |> to(email)
    |> subject("Welcome to Frayt!")
    |> assign(:email, email)
    |> assign(
      :url,
      Routes.session_url(FraytElixirWeb.Endpoint, :new,
        password_reset_code: password_reset_code,
        email: email
      )
    )
    |> assign(:password_reset_code, password_reset_code)
    |> assign(:name, name)
    |> render(:invitation)
  end

  def admin_reset_email(%{email: email, password_reset_code: password_reset_code}) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "admin_reset.html"})
    |> to(email)
    |> subject("Reset Your Frayt Password")
    |> assign(:email, email)
    |> assign(
      :url,
      Routes.session_url(
        FraytElixirWeb.Endpoint,
        :new,
        password_reset_code: password_reset_code,
        email: email
      )
    )
    |> assign(:password_reset_code, password_reset_code)
    |> render(:admin_reset)
  end

  def shipper_reset_email(%{
        email: email,
        password_reset_code: code,
        first_name: first_name,
        last_name: last_name
      }) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "shipper_reset.html"})
    |> to(email)
    |> subject("Reset Your Frayt Password")
    |> assign(:email, email)
    |> assign(:name, "#{first_name} #{last_name}")
    |> assign(:password_reset_code, code)
    |> render(:shipper_reset)
  end

  def shipper_invite_email(%{
        email: email,
        password_reset_code: code,
        first_name: first_name,
        last_name: last_name
      }) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "shipper_invite.html"})
    |> to(email)
    |> subject("Important next steps with your FRAYT account")
    |> assign(:email, email)
    |> assign(:name, "#{first_name} #{last_name}")
    |> assign(:password_reset_code, code)
    |> render(:shipper_invite)
  end

  def disable_driver_account_email(
        %{
          email: email,
          note: note,
          first_name: _first_name,
          last_name: _last_name
        } = driver_message
      ) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "disable_driver_account.html"})
    |> to(email)
    |> subject("Frayt Account Disabled")
    |> assign(:note, note)
    |> assign(:name, full_name(driver_message))
    |> render(:disable_driver_account)
  end

  def reactivate_driver_account_email(
        %{
          email: email,
          first_name: _first_name,
          last_name: _last_name
        } = driver_message
      ) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "reactivate_driver_account.html"})
    |> to(email)
    |> subject("Frayt Account Reactivated")
    |> assign(:name, full_name(driver_message))
    |> render(:reactivate_driver_account)
  end

  def approved_documents_email(driver_email, driver_name, state) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "driver_document_approved.html"})
    |> to(driver_email)
    |> subject("Documents Approved")
    |> assign(:name, driver_name)
    |> assign(:state, state)
    |> render("driver_document_approved.html")
    |> premail()
  end

  def rejected_documents_email(driver_email, driver_name) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "driver_document_rejected.html"})
    |> to(driver_email)
    |> subject("Documents Rejected")
    |> assign(:name, driver_name)
    |> render("driver_document_rejected.html")
    |> premail()
  end

  def send_rejection_letter(driver_email) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "driver_application_rejected.html"})
    |> to(driver_email)
    |> subject("Application Rejected")
    |> render("driver_application_rejected.html")
    |> premail()
  end

  def send_approval_letter(driver_email) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "driver_application_approved.html"})
    |> to(driver_email)
    |> subject("Application Approved!")
    |> render("driver_application_approved.html")
    |> premail()
  end

  def nps_score_email(%{
        email: email,
        name: name,
        shipper_id: shipper_id,
        nps_score_id: nps_score_id
      }) do
    base_email()
    |> put_html_layout({FraytElixir.EmailView, "nps_score.html"})
    |> to(email)
    |> subject("How did we do?")
    |> assign(:name, name)
    |> assign(:shipper_id, shipper_id)
    |> assign(:nps_score_id, nps_score_id)
    |> assign(
      :url,
      Routes.nps_score_path(FraytElixirWeb.Endpoint, :show, shipper_id, nps_score_id)
    )
    |> render("nps_score.html")
  end

  defp base_email do
    new_email()
    # Set a default from
    |> from(Application.get_env(:frayt_elixir, :support_email))
  end

  defp premail(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end
end
