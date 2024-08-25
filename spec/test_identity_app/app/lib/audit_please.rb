module AuditPlease
  extend ActiveSupport::Concern

  included do
    if name == 'Member'
      audited
      has_associated_audits
    else
      audited associated_with: :member
    end

    def audit_comment
      { backtrace: Kernel.caller.reject { |line| line.include? '/gems/' } }.to_json
    end
  end
end

class ActiveRecordAudit < Audited::Audit
  self.table_name = 'active_record_audits'
end

