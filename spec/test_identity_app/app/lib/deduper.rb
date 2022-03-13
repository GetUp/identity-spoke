module Deduper
  class << self
    def find_member(hash)
      return nil if hash.blank?

      attributes = make_attributes_from_hash(hash)

      member_id = `python lib/dedupe_client.py dedupe '#{attributes.to_json}' #{Thread.current.object_id}`.strip

      if member_id.present?
        member = Member.find(member_id)
        return member
      else
        return nil
      end
    end

    # Insert or update the blocks a member is part of (ie if their details change)
    def update_blocks_for_member(member_id)
      block_keys = `python lib/dedupe_client.py block #{member_id} #{Thread.current.object_id}`.strip
      member = Member.find(member_id)
      member.dedupe_blocks.destroy_all
      block_keys.split('|').each do |block_key|
        member.dedupe_blocks << DedupeBlock.new(block_key: block_key)
      end
    end

    def make_attributes_from_hash(hash)
      address = hash.try(:[], :addresses).try(:[], 0) || {}
      {
        email: Cleanser.cleanse_email(hash.try(:[], :emails).try(:[], 0).try(:[], :email)),
        phone: PhoneNumber.standardise_phone_number(hash.try(:[], :phones).try(:[], 0).try(:[], :phone)),
        first_name: hash[:firstname],
        last_name: hash[:lastname],
        line1: address[:line1],
        line2: address[:line2],
        town: address[:town],
        postcode: address[:postcode].try(:gsub, ' ', ''),
        state: address[:state],
        country: address[:country]
      }
    end
  end
end
