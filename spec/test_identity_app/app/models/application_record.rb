class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # This retains legacy AR behaviour
  # TODO: Remove this after tightening up foreign keys and updating factories
  self.belongs_to_required_by_default = false

  # Touch method that validates
  def touch!
    update! updated_at: DateTime.now
  end
end
