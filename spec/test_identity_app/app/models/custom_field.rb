class CustomField < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :member
  belongs_to :custom_field_key
end
