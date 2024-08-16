# frozen_string_literal: true

# == Schema Information
#
# Table name: phone_numbers
#
#  id         :integer          not null, primary key
#  member_id  :integer
#  phone      :text
#  created_at :datetime
#  updated_at :datetime
#  type       :text
#

class PhoneNumber < ApplicationRecord

  before_save :find_phone_type

  belongs_to :member
  belongs_to :phone_circle
  validates_uniqueness_of :phone, scope: :member
  validate :standard_phone
  validates :phone, presence: true, allow_blank: false

  MOBILE_TYPE = 'mobile'
  LANDLINE_TYPE = 'landline'

  scope :mobile, -> { where(phone_type: MOBILE_TYPE) }
  scope :landline, -> { where(phone_type: LANDLINE_TYPE) }
  scope :not_landline, -> { where.not(phone_type: LANDLINE_TYPE) }
  default_scope { order(updated_at: :desc) }

  def standard_phone
    if PhoneNumber.standardise_phone_number(self.phone).blank?
      errors.add(:phone, "is invalid")
    end
  end

  def find_phone_type
    self.phone = PhoneNumber.standardise_phone_number(self.phone)

    if Phony.plausible?(self.phone) && PhoneNumber.can_detect_mobiles?
      self.phone_type = infer_phone_type(self.phone)
    elsif PhoneNumber.should_lookup_phone_type?
      self.phone_type = Cleanser.is_mobile_number?(self.phone) ? MOBILE_TYPE : LANDLINE_TYPE
    else
      self.phone_type = MOBILE_TYPE
    end
  end

  def infer_phone_type(phone_number)
    ndc = Phony.split(phone_number)[1]
    return ndc == false || !ndc.start_with?(Settings.options.default_mobile_phone_national_destination_code.to_s) ? LANDLINE_TYPE : MOBILE_TYPE
  end

  def lookup_phone_type
    if self.phone_type.blank?
      self.find_phone_type
      self.save!
    end
    self.phone_type
  end

  # override getters and setters
  def phone=(val)
    write_attribute(:phone, PhoneNumber.standardise_phone_number(val))
  end

  def self.find_by_phone(arg)
    find_by phone: arg
  end

  def self.find_by(arg, *args)
    arg[:phone] = standardise_phone_number(arg[:phone]) if arg[:phone]
    super
  end

  def self.standardise_phone_number(input_phone)
    phone = input_phone.to_s.delete(' ').delete(')').delete('(').tr('-', ' ')
    return if phone.empty?

    if australian_phone_number?(phone)
      phone = normalise_australian_phone_number(phone)
    else
      phone = Phony.normalize(phone)
      unless Phony.plausible?(phone)
        phone = Phony.normalize("+#{country_code}#{input_phone}")
        return unless Phony.plausible?(phone)
      end
    end

    phone
  rescue Phony::NormalizationError, ArgumentError
  end

  def self.australian_phone_number?(phone)
    country_code == '61' && phone =~ /^\+*(61|0)*\d{9}$/
  end

  def self.normalise_australian_phone_number(phone)
    phone.delete('+').gsub(/^0*(\d{9})$/, '61\1')
  end

  def self.country_code
    Settings.options.default_phone_country_code.to_s
  end

  def self.can_detect_mobiles?
    !Settings.options.default_mobile_phone_national_destination_code.nil?
  end

  def self.should_lookup_phone_type?
    Settings.options.lookup_phone_type_on_create
  end
end
