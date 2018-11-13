class CustomFieldKey < ApplicationRecord
  include ReadWriteIdentity
  has_many :custom_fields
end
