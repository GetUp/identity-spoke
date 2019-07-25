module IdentitySpoke
  class SpokeMemberSyncPushSerializer < ActiveModel::Serializer
    attributes :external_id, :first_name, :last_name, :cell, :campaign_id, :custom_fields

    def external_id
      @object.id
    end

    def first_name
      @object.first_name ? @object.first_name : ''
    end

    def last_name
      @object.last_name ? @object.last_name : ''
    end

    def cell
      "+#{@object.mobile}"
    end

    def campaign_id
      instance_options[:campaign_id]
    end

    def custom_fields
      data = @object.flattened_custom_fields
      data['address'] = @object.address
      data['postcode'] = @object.postcode
      data["areas"] = @object.areas.each_with_index.map{|area, index|
        {
          name: area.name,
          code: area.code,
          area_type: area.area_type,
          party: area.party,
          representative_name: area.representative_name
        }
      }
      data.to_json
    end

    private

    def location
      address = @object.try(:address)
      postcode = address.try(:postcode)
      postcode.present? ? postcode : address.try(:town)
    end

  end
end
