module Orderable
  extend ActiveSupport::Concern

  included do
    scope :order_by_column_and_direction, ->(sort_column, sort_direction) {
      order("#{sort_column}" => sort_direction) if sort_column.present? && sort_direction.present?
    }

    # order by value similarity to column, most similar first
    scope :order_by_similarity, ->(column, value) {
      # table name quoting should work fine for schema names
      schema_name = ApplicationRecord.connection.quote_table_name(Settings.databases.extensions_schemas.core)
      column_name = ApplicationRecord.connection.quote_column_name(column)
      order_sql = Arel.sql("#{schema_name}.similarity(#{column_name}, ?) DESC")
      order_sql = Arel.sql(sanitize_sql_for_order([order_sql, value]))
      order(order_sql)
    }
  end
end
