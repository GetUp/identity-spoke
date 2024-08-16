class MemberExternalId < ApplicationRecord
  belongs_to :member

  validates_presence_of :member
  validates_uniqueness_of :external_id, scope: :system

  scope :with_system, ->(system) {
    where(system: system).order('updated_at DESC')
  }

  class << self
    def get_all_distinct_systems
      if (json = $redis.with { |r| r.get 'member_external_ids:distinct_systems' })
        JSON.parse(json)
      else
        []
      end
    end

    def generate_all_distinct_systems
      pluck_sql = Arel.sql('distinct system')
      distinct_systems = MemberExternalId.pluck(pluck_sql)
      $redis.with { |r| r.set 'member_external_ids:distinct_systems', distinct_systems }
    end
  end
end
