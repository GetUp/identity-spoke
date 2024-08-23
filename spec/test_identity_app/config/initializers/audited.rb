#./config/initializers/audited.rb
require "audited"

Audited::Railtie.initializers.each(&:run)

Audited.config do |config|
  config.audit_class = 'ActiveRecordAudit'
end
