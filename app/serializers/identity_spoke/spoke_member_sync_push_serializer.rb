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
      "+#{@object.mobile_if_can_be_detected_or_phone.phone}"
    end

    def campaign_id
      instance_options[:campaign_id]
    end

    def custom_fields
      data = @object.flattened_custom_fields
      data['postcode'] = @object.postcode if @object.postcode
      data['address'] = {
        line1: @object.address.line1,
        line2: @object.address.line2,
        suburb: @object.address.town,
        postcode: @object.address.postcode,
      } if @object.address
      data["areas"] = @object.areas.each_with_index.map { |area, _index|
        {
          name: area.name,
          code: area.code,
          area_type: area.area_type,
          party: area.party,
          representative_name: area.representative_name
        }
      } if @object.areas.each_with_index.count > 0
      data.to_json
    end

    private

    def location
      address = @object.try(:address)
      postcode = address.try(:postcode)
      (postcode.presence || address.try(:town))
    end
  end
end
