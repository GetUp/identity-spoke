module IdentitySpoke
  module ConnectionExtension
    def self.included(base)
      base.class_eval do
        def self.bulk_create(set=[], conflict=false)
          field_keys = *set[0].keys
          values_string = set.map do |x|
            values = field_keys.map do |field_key|
              if x[field_key].is_a? String
                ActiveRecord::Base.connection.quote(x[field_key])
              else
                x[field_key]
              end
            end
            "(#{values.join(',')})"
          end
          raw_sql = 'INSERT INTO %s (%s) VALUES %s ON CONFLICT DO NOTHING'
          sub_sql = [self.table_name, field_keys.join(', '), values_string.join(',')]
          formatted_sql = raw_sql % sub_sql
          self.connection.execute(formatted_sql)
        end
      end
    end
  end
end
