class IdentityBaseService
  # Factory stuff to make calling services easier.

  def self.call(...)
    new(...).call
  end
end
