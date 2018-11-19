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
      @object.flattened_custom_fields.to_json
    end
  end
end
