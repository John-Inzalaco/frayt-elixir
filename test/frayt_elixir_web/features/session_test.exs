defmodule FraytElixirWeb.SessionTest do
  use FraytElixirWeb.FeatureCase

  alias FraytElixir.Accounts

  feature "logging in and then out with valid user credentials", %{session: session} do
    user = insert(:admin_user)

    session
    |> SessionPage.visit_page()
    |> SessionPage.enter_credentials(user.user.email, user.user.password)
    |> assert_has(css("h1", text: "Matches"))
    |> logout_user()
    |> assert_has(css("h1", text: "logged out"))
  end

  feature "send reset password link", %{session: session} do
    %{user: %{email: email}} = insert(:admin_user)

    session
    |> SessionPage.visit_page()
    |> click(link("Forgot Password?"))
    |> assert_has(css("h1", text: "Reset Password"))
    |> assert_has(css("label", text: "Email"))
    |> assert_has(css("#session_email"))
    |> assert_has(button("Send Email"))
    |> assert_has(css("a", text: "Cancel"))
    |> click(button("Send Email"))
    |> assert_has(css("p", text: "Invalid email"))
    |> fill_in(text_field("session[email]"), with: email)
    |> click(button("Send Email"))
    |> assert_has(css("p", text: "Email sent"))
  end

  feature "reset password flow", %{session: session} do
    %{user: %{email: email, id: id}} = insert(:admin_user)

    session
    |> SessionPage.visit_page()
    |> click(link("Forgot Password?"))
    |> fill_in(text_field("session[email]"), with: email)
    |> click(button("Send Email"))

    %{password_reset_code: code} = Accounts.get_user!(id)

    session =
      session
      |> SessionPage.visit_page("/admin?password_reset_code=#{code}&email=#{email}")
      |> fill_in(text_field("session[password]"), with: "")
      |> fill_in(text_field("session[password_confirmation]"), with: "")
      |> click(button("Reset Password"))
      |> assert_has(
        css("p", text: "Password can't be blank; Password confirmation can't be blank")
      )

    session =
      session
      |> fill_in(text_field("session[password]"), with: "test")
      |> fill_in(text_field("session[password_confirmation]"), with: "test")
      |> click(button("Reset Password"))
      |> assert_has(css("p", text: "Password must contain a special character"))

    session =
      session
      |> fill_in(text_field("session[password]"), with: "t123*")
      |> fill_in(text_field("session[password_confirmation]"), with: "t123*")
      |> click(button("Reset Password"))
      |> assert_has(css("p", text: "Password must contain at least 8 characters"))

    session =
      session
      |> fill_in(text_field("session[password]"), with: "test*******")
      |> fill_in(text_field("session[password_confirmation]"), with: "test*******")
      |> click(button("Reset Password"))
      |> assert_has(css("p", text: "Password must contain a number"))

    session
    |> fill_in(text_field("session[password]"), with: "newpassword123*")
    |> fill_in(text_field("session[password_confirmation]"), with: "newpassword12*")
    |> click(button("Reset Password"))
    |> assert_has(css("p", text: "Password confirmation must match"))

    session
    |> fill_in(text_field("session[password]"), with: "newpassword123*")
    |> fill_in(text_field("session[password_confirmation]"), with: "newpassword123*")
    |> click(button("Reset Password"))
    |> assert_has(css("p", text: "Password changed successfully!"))
  end
end
