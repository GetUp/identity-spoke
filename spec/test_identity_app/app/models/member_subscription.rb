# == Schema Information
#
# Table name: member_subscriptions
#
#  id                 :integer          not null, primary key
#  subscription_id    :integer
#  member_id          :integer
#  unsubscribed_at    :datetime
#  unsubscribe_reason :text
#  subscribed_at      :datetime
#  subscribe_reason   :text
#  created_at         :datetime
#  updated_at         :datetime
#

class MemberSubscription < ApplicationRecord
  attr_accessor :subscribable
  attr_accessor :operation_reason

  self.table_name = 'member_subscriptions'
  belongs_to :subscription
  belongs_to :member
  belongs_to :unsubscribe_mailing, class_name: 'Mailing', optional: true
  has_many :member_subscription_events

  after_create :record_member_subscription_create_event
  around_update :record_member_subscription_update_event

  validates_uniqueness_of :member, scope: :subscription

  def record_member_subscription_create_event
    record_member_subscription_event(action: 'create', subscription_status_changed: true)
  end

  def record_member_subscription_update_event
    # unsubscribed_at can change without actually changing if someone is subscribed or not
    # so we have to also check the before and after values
    subscribe = unsubscribed_at_was.nil?
    unsubscribe = unsubscribed_at_was.present? && unsubscribed_at.nil?
    subscription_status_changed = unsubscribed_at_changed? && (subscribe || unsubscribe)

    yield

    record_member_subscription_event(action: 'update', subscription_status_changed: subscription_status_changed)
  end

  def record_member_subscription_event(action:, subscription_status_changed:)
  end

  def latest_member_subscription_event
    member_subscription_events.last
  end

  def latest_subscribable
    latest_member_subscription_event&.subscribable
  end

  def unsubscribed_permanently?
    return !unsubscribed_at.nil? && permanent
  end
end
