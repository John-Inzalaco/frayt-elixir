defmodule FraytElixir.Test.FakePassword do
  def hash_password(_, _), do: %{hashed_password: "gobbledygook"}

  def check_password(nil, _, _), do: {:error, "invalid user-identifier"}
  def check_password(user, "password", _), do: {:ok, user}
  def check_password(user, "secretpassword", _), do: {:ok, user}
  def check_password(user, "ABC456", _), do: {:ok, user}
  def check_password(user, "somesupersecretstuff", _), do: {:ok, user}

  def check_password(_, _, _), do: {:error, "invalid password"}
end
