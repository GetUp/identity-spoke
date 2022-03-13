class MemberExternalId < ApplicationRecord
  belongs_to :member

  validates_presence_of :member
  validates_uniqueness_of :external_id, scope: :system

  class << self
    def get_all_distinct_systems
      if (json = $redis.with { |r| r.get 'member_external_ids:distinct_systems' })
        JSON.parse(json)
      else
        []
      end
    end

    def generate_all_distinct_systems
      distinct_systems = MemberExternalId.pluck('distinct system')
      $redis.with { |r| r.set 'member_external_ids:distinct_systems', distinct_systems }
    end
  end
end
