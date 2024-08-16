# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id          :integer          not null, primary key
#  name        :text
#  description :text
#  deleted_at  :datetime
#  created_at  :datetime
#  updated_at  :datetime
#

class Subscription < ApplicationRecord
  # subscription ids for various channels
  EMAIL_SLUG = 'default-email'
  SMS_SLUG = 'default-sms'
  NOTIFICATION_SLUG = 'default-notification'
  FACEBOOK_SLUG = 'default-facebook'
  CALLING_SLUG = 'default-calling'
  POST_SLUG = 'default-post'
  PROFILING_SLUG = 'default-profiling'

  EMAIL_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::EMAIL_SLUG do |sub|
    sub.name = 'Email'
    sub.is_default = true
  end

  UNSUBSCRIBE_EMAIL_URL = "#{Settings.app.inbound_url}/subscriptions/unsubscribe?subscription=#{Subscription::EMAIL_SUBSCRIPTION.id}".freeze

  SMS_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::SMS_SLUG do |sub|
    sub.name = 'SMS'
  end

  NOTIFICATION_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::NOTIFICATION_SLUG do |sub|
    sub.name = 'Push Notification'
  end

  FACEBOOK_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::FACEBOOK_SLUG do |sub|
    sub.name = 'Facebook Audience'
  end

  CALLING_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::CALLING_SLUG do |sub|
    sub.name = 'Calling'
  end

  POST_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::POST_SLUG do |sub|
    sub.name = 'Post'
  end

  # 'Profiling' is a broad term and can mean, eg. linking members to demographics, using predictive modelling
  # or machine learning techniques to model future member behaviour based on past behaviour of your members, etc...
  PROFILING_SUBSCRIPTION = Subscription.find_or_create_by! slug: Subscription::PROFILING_SLUG do |sub|
    sub.name = 'Profiling'
  end

  has_many :member_subscriptions
  has_many :member_subscription_events, through: :member_subscriptions
  has_many :subscribables, through: :member_subscription_events
  has_many :members, through: :member_subscriptions

  scope :defaults, -> { where(is_default: true, deleted_at: nil) }
  scope :non_defaults, -> { where(is_default: false, deleted_at: nil) }

  # Currently loads unsubs from Ctrlshift
  def self.load_from_csv(row)
    return if row['unsubscribe_organisation'].eql?('f')

    member =
      begin
        Member.find_or_create_by!(email: row['email'].downcase) do |m|
          m.entry_point = 'ctrlshift_unsubscribe'
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end

    # see if this is newer than the subscription record we have
    if (
      existing_subscription = MemberSubscription.find_by(
        member_id: member.id,
        subscription: Subscription::EMAIL_SUBSCRIPTION
      )
    )
      return if existing_subscription.updated_at >= row['updated_at']
    end

    # unsubscribe if all is well
    member.unsubscribe
  end

  def icon
    {
      'Main list' => 'envelope',
      'email' => 'envelope',
      'Email' => 'envelope',
      'notification' => 'bell',
      'Push Notification' => 'bell',
      'text' => 'phone',
      'SMS' => 'phone',
      'Calling' => 'earphone',
      'Facebook Audience' => 'user'
    }[name]
  end
end
