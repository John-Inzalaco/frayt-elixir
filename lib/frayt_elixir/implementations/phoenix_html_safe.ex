defimpl Phoenix.HTML.Safe, for: ExPhoneNumber.Model.PhoneNumber do
  def to_iodata(phone_number) do
    Phoenix.HTML.Safe.to_iodata(ExPhoneNumber.format(phone_number, :international))
  end
end
