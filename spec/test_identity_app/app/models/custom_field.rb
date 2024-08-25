class CustomField < ApplicationRecord
  include AuditPlease

  belongs_to :member
  belongs_to :custom_field_key

  validates_presence_of :member
  validates_presence_of :custom_field_key

  class << self
    def get_all_key_value_pairs
      if (json = $redis.with { |r| r.get 'custom_field:key_value_pairs' })
        JSON.parse(json).map(&:symbolize_keys)
      else
        []
      end
    end

    def generate_all_key_value_pairs
      data = CustomFieldKey.limit(100).map { |key|
        key.custom_fields.limit(100).map { |field|
          values = field.data.starts_with?('["') ? JSON::parse(field.data) : [field.data]
          values.map { |value|
            { key: key.name, value: value }
          }
        }
      }.flatten.uniq
      $redis.with { |r| r.set 'custom_field:key_value_pairs', data.to_json }
    end
  end
end
