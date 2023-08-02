defmodule FraytElixir.EmailTest do
  use FraytElixir.DataCase
  alias FraytElixir.Email
  import FraytElixir.Factory

  test "invitation email" do
    user = %{email: "some@example.com", password_reset_code: nil, name: nil}
    email = Email.invitation_email(user)

    assert email.from == Application.get_env(:frayt_elixir, :support_email)
    assert email.subject == "Welcome to Frayt!"
  end

  test "admin reset email" do
    user = %{email: "some@example.com", password_reset_code: nil}
    email = Email.admin_reset_email(user)

    assert email.from == Application.get_env(:frayt_elixir, :support_email)
    assert email.subject == "Reset Your Frayt Password"
    assert email.text_body =~ "You have requested to reset your Frayt admin password."
  end

  test "shipper reset email" do
    user = %{
      email: "some@example.com",
      password_reset_code: nil,
      first_name: "Some",
      last_name: "Name"
    }

    email = Email.shipper_reset_email(user)

    assert email.from == Application.get_env(:frayt_elixir, :support_email)
    assert email.subject == "Reset Your Frayt Password"

    assert email.text_body =~
             "Please sign into your account and reset your password using the following temporary password:"
  end

  test "shipper invite email" do
    user = %{
      email: "some@example.com",
      password_reset_code: nil,
      first_name: "Some",
      last_name: "Name"
    }

    email = Email.shipper_invite_email(user)

    assert email.from == Application.get_env(:frayt_elixir, :support_email)
    assert email.subject == "Important next steps with your FRAYT account"
  end

  describe "document approval" do
    test "approved documents for new drivers" do
      email = Email.approved_documents_email("driver@mail.com", "driver name", :applying)

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Documents Approved"
      assert email.text_body =~ "Your application can now progress to the next stage"
    end

    test "approved documents for registered drivers" do
      email = Email.approved_documents_email("driver@mail.com", "driver name", :registered)

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Documents Approved"
      assert email.text_body =~ "you can start taking deliveries again"
    end

    test "approved_documents_email" do
      email = Email.approved_documents_email("driver@mail.com", "driver name", :approved)

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Documents Approved"
      assert email.text_body =~ "Your account has been reinstated"
    end

    test "rejected_documents_email" do
      email = Email.rejected_documents_email("driver@mail.com", "driver name")

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Documents Rejected"
      assert email.text_body =~ "Please proceed to the FRAYT Driver app to reupload some"
    end

    test "send_rejection_letter" do
      email = Email.send_rejection_letter("driver@mail.com")

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Application Rejected"
      assert email.text_body =~ "Frayt application was rejected"
    end

    test "send_approval_letter" do
      email = Email.send_approval_letter("driver@mail.com")

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.subject == "Application Approved!"
      assert email.text_body =~ "Congratulations, you’ve been approved to drive"
    end
  end

  describe "match_status_email" do
    test "sends an email" do
      match = build(:accepted_match)
      mst = build(:match_state_transition)

      email =
        Email.match_status_email(match, [mst: mst], %{
          to: {"Example", "example@email.com"},
          subject: "Match has been accepted"
        })

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.to == {"Example", "example@email.com"}
      assert email.subject == "Match has been accepted"
      assert email.text_body =~ "Driver Assigned"
      assert email.text_body =~ "Accepted at"
    end

    test "sends an email with cc and bcc" do
      match = build(:accepted_match)
      mst = build(:match_state_transition)

      email =
        Email.match_status_email(match, [mst: mst], %{
          to: "example@email.com",
          cc: ["example1@email.com", "example2@email.com"],
          bcc: ["example3@email.com"],
          subject: "Match has been accepted"
        })

      assert email.from == Application.get_env(:frayt_elixir, :support_email)
      assert email.to == "example@email.com"
      assert email.cc == ["example1@email.com", "example2@email.com"]
      assert email.bcc == ["example3@email.com", "notifications@frayt.com"]
    end
  end
end
