module Searchable
  extend ActiveSupport::Concern

  included do
    scope :with_author, ->(author_id) {
      where(author_id: author_id.to_i) if author_id && author_id.present?
    }

    scope :with_name_like, ->(query) {
      where('name ilike ?', '%' + query + '%') if query && query.present?
    }

    scope :with_system, ->(system) {
      where(system: system) if system && system.present? && system != 'all'
    }

    scope :with_subsystem, ->(subsystem) {
      where(subsystem: subsystem) if subsystem && subsystem.present? && subsystem != 'all'
    }
  end
end
