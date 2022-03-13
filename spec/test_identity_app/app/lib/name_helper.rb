module NameHelper
  # to allow intelligent 'upserting' of names
  def self.combine_names(old_name, new_name)
    old_name = old_name.slice(:first_name, :middle_names, :last_name)
    new_name = new_name.slice(:first_name, :middle_names, :last_name)

    is_new_name = false
    combined_name = old_name

    new_name.each do |key, new_value|
      new_value = new_value.to_s.strip
      current_value = old_name[key].to_s.strip
      if current_value.downcase.starts_with?(new_value.downcase) || new_value.downcase.starts_with?(current_value.downcase)
        if new_value.length > current_value.length
          combined_name[key.to_sym] = new_value
        end
      else
        is_new_name = true
      end
    end

    if is_new_name
      combined_name = new_name.select { |_k, v| v.present? }
    end

    return { first_name: nil, middle_names: nil, last_name: nil }.merge(combined_name)
  end
end
