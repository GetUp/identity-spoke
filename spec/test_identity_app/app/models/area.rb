# == Schema Information
#
# Table name: areas
#
#  id         :integer          not null, primary key
#  name       :text
#  code       :text
#  mapit      :integer
#  area_type  :text
#  created_at :datetime
#  updated_at :datetime
#

class Area < ApplicationRecord
  has_many :area_zips
  has_many :area_memberships
  has_many :members, through: :area_memberships
  has_and_belongs_to_many :canonical_addresses

  validates_uniqueness_of :code, scope: :area_type

  def self.area_types
    Settings.geography.area_types.keys
  end

  def self.area_type_friendly_names
    Settings.geography.area_types
  end

  def self.icons
    {
      'pcon_new' => 'building',
      'eer' => 'euro-sign',
      'locality' => '',
      'federal_electoral_district' => '',
      'canada_province' => ''
    }
  end

  def self.parties
    {
      'SNP' => 'Scottish National Party',
      'Con' => 'Conservative Party',
      'Lab' => 'Labour Party',
      'DUP' => 'DUP',
      'SDLP' => 'SDLP',
      'UUP' => 'Ulster Unionist Party',
      'SF' => 'Sinn Fein',
      'Ind' => 'Independent',
      'Green' => 'Green Party',
      'LD' => 'Liberal Democrat',
      'UKIP' => 'UKIP',
      'PC' => 'Plaid Cymru',
      'Spk' => 'The Speaker'
    }
  end

  def icon
    area_icon || Area.icons[area_type]
  end

  def friendly_name
    "#{name} (#{area_type_friendly_name})"
  end

  def area_type_friendly_name
    Area.area_type_friendly_names[area_type]
  end
end
