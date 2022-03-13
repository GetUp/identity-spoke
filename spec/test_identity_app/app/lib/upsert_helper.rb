module UpsertHelper
  # Returns a copy of the original hash, with any keys specified and present as
  # Strings parsed assuming UTC.
  # Raises an ArgumentError if a key is present and a string, but not parseable
  def self.parse_dates_as_utc(hash, keys)
    hash.map { |key, value|
      next { key => value } unless keys.include?(key) && value.present? && value.is_a?(String)
      raise ArgumentError.new("Key ':#{key}' with value '#{value}' is not parsable as a datetime") unless (
        parsed_value = ActiveSupport::TimeZone.new('UTC').parse(value)
      )

      { key => parsed_value }
    }.reduce({}, :merge)
  end

  def self.extract_cons_hash_from_flat_data(payload)
    cons_hash = {
      emails: [
        { email: payload['email'].downcase.strip }
      ],
      phones: [
        { phone: payload['phone'] }
      ],
      addresses: [
        {
          line1: payload['line1'],
          line2: payload['line2'],
          town: payload['town'],
          state: payload['state'],
          postcode: payload['postcode'],
          country: payload['country']
        }
      ]
    }
    if payload['name'].present?
      cons_hash[:name] = payload['name']
    else
      cons_hash[:firstname] = payload['first_name']
      cons_hash[:lastname] = payload['last_name']
    end

    cons_hash
  end

  def self.get_regular_donation_payload(member, parsed_payload, member_action)
    {
      member_id: member.id,
      member_action_id: member_action.try(:id),
      medium: parsed_payload['regular_donation_system'],
      external_id: parsed_payload['regular_donation_external_id'],
      current_amount: parsed_payload['regular_donation_amount'] || parsed_payload['amount'],
      frequency: parsed_payload['regular_donation_frequency'],
      started_at: parsed_payload['regular_donation_started_at'],
      ended_at: parsed_payload['regular_donation_ended_at'],
      source: parsed_payload['regular_donation_source'],
      updated_at: parsed_payload['created_at'],
      ended_reason: parsed_payload['ended_reason']
    }.compact
  end
end
