class PhoneNumber < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :member

  MOBILE_TYPE = 'mobile'
  LANDLINE_TYPE = 'landline'

  scope :mobile, -> { where(phone_type: MOBILE_TYPE) }
  scope :landline, -> { where(phone_type: LANDLINE_TYPE) }

  def self.standardise_phone_number(phone)
    phone = phone.to_s
    phone = phone.delete(' ').delete(')').delete('(').tr('-', ' ')
    return nil if phone.empty?

    phone = Phony.normalize(phone)

    unless Phony.plausible?(phone)
      phone = Phony.normalize(phone)
      phone = "+#{Settings.options.default_phone_country_code}#{phone}"

      phone = Phony.normalize(phone)
      phone = nil unless Phony.plausible?(phone)
    end

    phone = Phony.normalize(phone)
    return phone
  rescue Phony::NormalizationError, ArgumentError
    return nil
  end
end
