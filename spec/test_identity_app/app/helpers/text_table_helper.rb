module TextTableHelper
  MAX_FIELD_WIDTH = 100

  def tabulate_all(data, config)
    result = ''
    if (root_cfg = config[:_root])
      result << tabulate(data, root_cfg)
    end
    config.reject { |k, _| k == :_root }.each do |key, cfg|
      if cfg.is_a? Hash
        cfg[:heading] ||= key.to_s.tr('_', ' ').capitalize
        result << tabulate(data[key], cfg)
      elsif cfg.is_a? Array
        result << tabulate(
          data[key],
          heading: key.to_s.tr('_', ' ').capitalize,
          fields: cfg
        )
      else
        result << tabulate(data[key], heading: key.to_s.tr('_', ' ').capitalize)
      end
    end
    result
  end

  def tabulate(data, config = {})
    return '' if data.blank?

    heading = config[:heading] ? "\r\n\r\n*** #{config[:heading]} ***\r\n\r\n" : "\r\n"
    fields = config[:fields] || (data.is_a?(Hash) ? data.keys : data[0].keys)
    sort_field = config[:sort_field] || fields[-1]
    widths = get_max_widths(data, fields)

    column_header_row = ''
    underline_row = ''
    table_rows = ''

    fields.each do |field|
      field_name = field.to_s.split('.')[-1].tr('_', ' ')
      field_width = widths[field]
      column_header_row << "#{field_name.truncate(MAX_FIELD_WIDTH).capitalize.ljust(field_width, ' ')}  "
      underline_row << "#{'-' * field_width}  "
      if data.is_a? Hash
        table_rows << format_value(data, field, widths)
      end
    end

    if data.is_a? Array
      data.sort_by! { |row| row[sort_field] }
      data.reverse! if config[:descending]
      data.each do |row|
        fields.each do |field|
          table_rows << format_value(row, field, widths)
        end
        table_rows << "\r\n"
      end
    end

    "#{heading}#{column_header_row}\r\n#{underline_row}\r\n#{table_rows}\r\n"
  end

  def get_max_widths(data, fields)
    widths = {}
    if data.is_a? Array
      data.each { |row| get_max_widths_row(fields, widths, row) }
    elsif data.is_a? Hash
      get_max_widths_row(fields, widths, data)
    end
    widths
  end

  def get_max_widths_row(fields, widths, row)
    fields.each do |field|
      value = get_value(row, field)
      field_name = field.to_s.split('.')[-1]
      widths[field] = [[field_name.length, (widths[field] || 0), value ? value.length : 0].max, MAX_FIELD_WIDTH].min
    end
  end

  def format_value(data, field, widths)
    value = get_value(data, field)
    "#{value.truncate(MAX_FIELD_WIDTH).ljust(widths[field] || field.to_s.split('.')[-1].length, ' ')}  "
  end

  def get_value(data, field)
    return '' unless data

    if (parts = field.to_s.split('.')).size == 1
      data[field].to_s
    else
      get_value(data[parts[0].to_s], parts[1..-1].join('.'))
    end
  end
end
