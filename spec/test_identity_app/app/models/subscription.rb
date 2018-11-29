class Subscription < ApplicationRecord
  include ReadWriteIdentity
  EMAIL_SUBSCRIPTION = 1
  SMS_SUBSCRIPTION = 2
  NOTIFICATION_SUBSCRIPTION = 3
  CALLING_SUBSCRIPTION = 4
end
