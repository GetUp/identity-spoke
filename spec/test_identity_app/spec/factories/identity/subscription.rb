FactoryBot.define do
  factory :subscription do
    factory :sms_subscription do
      name { 'SMS' }
      id { Subscription::SMS_SUBSCRIPTION }
    end
  end
end
