if Settings.rollbar.api_key.present?
  Notify = Rollbar
else
  module Notify
    class << self
      def method_missing(m, *args, &_block)
        Rails.logger.warn("Call to Notify##{m} with args #{args.inspect} was made, but no notifier set up or is implemented (Bugsnag, Airbrake)")
      end
    end
  end
end
