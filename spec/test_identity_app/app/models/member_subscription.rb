class MemberSubscription < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :member
  belongs_to :subscription

  def unsubscribed_permanently?
    return !unsubscribed_at.nil? && permanent
  end
end
