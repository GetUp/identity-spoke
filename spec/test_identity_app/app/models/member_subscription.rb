class MemberSubscription < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  belongs_to :member
  belongs_to :subscription

  def unsubscribed_permanently?
    return !unsubscribed_at.nil? && permanent
  end
end
