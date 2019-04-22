class CustomFieldKey < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  has_many :custom_fields
end
