# == Schema Information
#
# Table name: member_subscription_events
#
#  id                               :integer          not null, primary key
#  action                           :string
#  operation                        :string
#  operation_reason                 :text
#  operation_permanently_deferred   :boolean
#  subscription_status_changed      :boolean
#  member_subscription_id           :integer
#  subscribable_id                  :integer
#  subscribable_type                :string
#  created_at                       :datetime
#  updated_at                       :datetime
#

class MemberSubscriptionEvent < ApplicationRecord
  belongs_to :member_subscription
  belongs_to :subscribable, polymorphic: true

  validates :action, inclusion: { in: %w(create update) }
  validates :operation, inclusion: { in: %w(subscribe unsubscribe) }

  scope :subscriptions, -> {
    where(operation: 'subscribe', subscription_status_changed: true)
  }

  scope :new_subscriptions, -> {
    where(operation: 'subscribe', action: 'create', subscription_status_changed: true)
  }

  scope :resubscriptions, -> {
    where(operation: 'subscribe', action: 'update', subscription_status_changed: true)
  }

  scope :unsubscriptions, -> {
    where(operation: 'unsubscribe', subscription_status_changed: true)
  }
end
