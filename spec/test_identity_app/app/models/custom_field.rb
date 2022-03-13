class CustomField < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
    
  belongs_to :member
  belongs_to :custom_field_key
end
