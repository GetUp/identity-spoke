class CustomFieldKey < ApplicationRecord
  has_many :custom_fields
  has_many :members, through: :custom_fields

  validates_uniqueness_of :name

  def self.name_contains(search)
    search_sql = Arel.sql("%#{sanitize_sql_like(search)}%")
    order_sql = Arel.sql("#{ApplicationRecord.connection.quote_table_name(Settings.databases.extensions_schemas.core)}.similarity(name, ?)")
    order_sql = Arel.sql(sanitize_sql_for_order([order_sql, search]))
    where('name ILIKE ?', search_sql).order(order_sql)
  end
end
