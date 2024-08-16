class Initial < ActiveRecord::Migration[7.0]

  enable_extension "btree_gin"
  enable_extension "btree_gist"
  enable_extension "intarray"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "action_keys", id: :serial, force: :cascade do |t|
    t.integer "action_id", null: false
    t.text "key"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["action_id", "key"], name: "index_action_keys_on_action_id_and_key", unique: true
    t.index ["action_id"], name: "index_action_keys_on_action_id"
    t.index ["key"], name: "index_action_keys_on_key"
  end

  create_table "actions", force: :cascade do |t|
    t.text "name"
    t.text "action_type"
    t.text "technical_type"
    t.string "external_id"
    t.integer "old_action_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "campaign_id"
    t.text "description"
    t.text "status"
    t.string "public_name"
    t.string "language"
    t.index ["campaign_id"], name: "index_actions_on_campaign_id"
    t.index ["external_id", "technical_type", "language"], name: "index_actions_on_external_id_and_technical_type_and_language", unique: true
    t.index ["old_action_id"], name: "index_actions_on_old_action_id"
  end

  create_table "actions_mailings", force: :cascade do |t|
    t.integer "mailing_id", null: false
    t.integer "action_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["action_id"], name: "index_actions_mailings_on_action_id"
    t.index ["mailing_id"], name: "index_actions_mailings_on_mailing_id"
  end

  create_table "active_record_audits", id: :serial, force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.json "audited_changes"
    t.integer "version", default: 0
    t.text "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at", precision: nil
    t.index ["associated_id", "associated_type"], name: "associated_index"
    t.index ["auditable_id", "auditable_type"], name: "auditable_index"
    t.index ["created_at"], name: "index_active_record_audits_on_created_at"
    t.index ["request_uuid"], name: "index_active_record_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "addresses", force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "line1"
    t.text "line2"
    t.text "town"
    t.text "postcode"
    t.text "country"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "canonical_address_id"
    t.string "state"
    t.index ["canonical_address_id"], name: "index_addresses_on_canonical_address_id"
    t.index ["member_id"], name: "index_addresses_on_member_id"
  end

  create_table "anonymization_log", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.text "reason", null: false
    t.json "external_ids"
    t.datetime "anonymization_started_at", precision: nil, null: false
    t.datetime "anonymization_finished_at", precision: nil
    t.index ["member_id"], name: "index_anonymization_log_on_member_id"
  end

  create_table "api_users", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "token"
    t.boolean "active", default: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.bigint "role_id"
    t.index ["role_id"], name: "index_api_users_on_role_id"
    t.index ["token"], name: "index_api_users_on_token"
  end

  create_table "area_memberships", force: :cascade do |t|
    t.integer "area_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.float "probability"
    t.index ["area_id"], name: "index_area_memberships_on_area_id"
    t.index ["member_id"], name: "index_area_memberships_on_member_id"
  end

  create_table "area_zips", id: :serial, force: :cascade do |t|
    t.integer "area_id", null: false
    t.string "zip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.float "proportion_of_area"
    t.float "proportion_of_zip"
    t.index ["area_id"], name: "index_area_zips_on_area_id"
    t.index ["zip"], name: "index_area_zips_on_zip"
  end

  create_table "areas", force: :cascade do |t|
    t.text "name"
    t.text "code"
    t.integer "mapit"
    t.text "area_type"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "party"
    t.text "runner_up_party"
    t.integer "majority"
    t.integer "vote_count"
    t.text "representative_name"
    t.text "representative_gender"
    t.string "representative_identifier"
    t.integer "display_priority"
    t.text "area_icon"
    t.index ["area_type", "code"], name: "index_areas_on_area_type_and_code"
  end

  create_table "areas_canonical_addresses", id: :serial, force: :cascade do |t|
    t.integer "canonical_address_id", null: false
    t.integer "area_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["area_id"], name: "index_areas_canonical_addresses_on_area_id"
    t.index ["canonical_address_id"], name: "index_areas_canonical_addresses_on_canonical_address_id"
  end

  create_table "audits", id: :serial, force: :cascade do |t|
    t.integer "member_id"
    t.text "path"
    t.string "request_method"
    t.string "ip"
    t.text "request_data"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id"], name: "index_audits_on_member_id"
    t.index ["path"], name: "index_audits_on_path"
  end

  create_table "call_sessions", force: :cascade do |t|
    t.integer "member_id"
    t.integer "caller_id"
    t.integer "stage_id"
    t.text "twilio_call_sid"
    t.text "to"
    t.text "from"
    t.integer "duration"
    t.boolean "completed"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "campaigns", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "issue_id"
    t.text "description"
    t.integer "author_id"
    t.integer "controlshift_campaign_id"
    t.text "campaign_type"
    t.float "latitude"
    t.float "longitude"
    t.text "location"
    t.text "image"
    t.text "url"
    t.text "slug"
    t.text "moderation_status"
    t.datetime "finished_at", precision: nil
    t.string "target_type"
    t.string "outcome"
    t.string "languages", default: [], array: true
    t.index ["author_id"], name: "index_campaigns_on_author_id"
    t.index ["issue_id"], name: "index_campaigns_on_issue_id"
  end

  create_table "canonical_addresses", id: :serial, force: :cascade do |t|
    t.string "official_id"
    t.text "line1"
    t.text "line2"
    t.text "town"
    t.string "state"
    t.string "postcode"
    t.string "country"
    t.float "latitude"
    t.float "longitude"
    t.text "search_text"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "suburb"
    t.index ["official_id"], name: "index_canonical_addresses_on_official_id"
    t.index ["postcode", "search_text"], name: "index_canonical_addresses_on_postcode_and_search_text", opclass: { search_text: :gist_trgm_ops }, using: :gist
    t.index ["search_text"], name: "canonical_addresses_search_text", opclass: :gist_trgm_ops, using: :gist
  end

  create_table "clicks", force: :cascade do |t|
    t.integer "member_mailing_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "link_id", null: false
    t.text "ip_address"
    t.text "user_agent"
    t.index ["link_id"], name: "index_clicks_on_link_id"
    t.index ["member_mailing_id"], name: "index_clicks_on_member_mailing_id"
  end

  create_table "conditional_journeys", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "description"
    t.text "slug"
    t.text "options"
    t.text "default_url"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "conditional_list_members", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "conditional_list_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["conditional_list_id"], name: "index_conditional_list_members_on_conditional_list_id"
    t.index ["member_id"], name: "index_conditional_list_members_on_member_id"
  end

  create_table "conditional_lists", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "conditional_list_members_count", default: 0
  end

  create_table "consent_texts", id: :serial, force: :cascade do |t|
    t.string "public_id", null: false
    t.string "consent_short_text", null: false
    t.string "full_legal_text_link", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["public_id"], name: "index_consent_texts_on_public_id", unique: true
  end

  create_table "contact_campaigns", id: :serial, force: :cascade do |t|
    t.text "name"
    t.integer "external_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "system"
    t.string "contact_type"
  end

  create_table "contact_response_keys", id: :serial, force: :cascade do |t|
    t.integer "contact_campaign_id"
    t.string "key"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["contact_campaign_id"], name: "index_contact_response_keys_on_contact_campaign_id"
  end

  create_table "contact_responses", id: :serial, force: :cascade do |t|
    t.integer "contact_id", null: false
    t.text "value"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "contact_response_key_id", null: false
    t.index ["contact_id"], name: "index_contact_responses_on_contact_id"
    t.index ["contact_response_key_id"], name: "index_contact_responses_on_contact_response_key_id"
  end

  create_table "contacts", id: :serial, force: :cascade do |t|
    t.integer "contactee_id", null: false
    t.integer "contactor_id"
    t.integer "contact_campaign_id"
    t.string "external_id"
    t.string "contact_type"
    t.string "system"
    t.string "status"
    t.text "notes"
    t.integer "duration"
    t.datetime "happened_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.json "data", default: "{}"
    t.index ["contact_campaign_id"], name: "index_contacts_on_contact_campaign_id"
    t.index ["contact_type"], name: "index_contacts_on_contact_type"
    t.index ["contactee_id"], name: "index_contacts_on_contactee_id"
    t.index ["contactor_id"], name: "index_contacts_on_contactor_id"
    t.index ["external_id"], name: "index_contacts_on_external_id"
  end

  create_table "controlshift_consent_mappings", force: :cascade do |t|
    t.bigint "controlshift_consent_id", null: false
    t.bigint "consent_text_id", null: false
    t.string "method", null: false
    t.string "opt_in_level", null: false
    t.string "opt_in_option", null: false
    t.string "opt_out_level", null: false
    t.string "opt_out_option", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["consent_text_id"], name: "index_controlshift_consent_mappings_on_consent_text_id"
    t.index ["controlshift_consent_id", "consent_text_id"], name: "idx_ctrlshift_consents_on_ctrlshift_consent_and_consent_text", unique: true
    t.index ["controlshift_consent_id"], name: "index_controlshift_consent_mappings_on_controlshift_consent_id"
  end

  create_table "controlshift_consents", force: :cascade do |t|
    t.string "controlshift_consent_type", null: false
    t.integer "controlshift_version_id", null: false
    t.string "controlshift_consent_external_id", null: false
    t.index ["controlshift_consent_type", "controlshift_version_id"], name: "idx_ctrlshift_consents_on_consent_type_and_version_id", unique: true
  end

  create_table "ctrlshift_webhooks", id: :serial, force: :cascade do |t|
    t.text "job_type"
    t.text "table"
    t.text "url"
    t.text "error"
    t.boolean "processed"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "custom_field_keys", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "read_only", default: false, null: false
    t.boolean "categorical", default: false, null: false
    t.string "categories", default: [], array: true
    t.index ["name"], name: "index_custom_field_keys_on_name", unique: true
  end

  create_table "custom_fields", id: :serial, force: :cascade do |t|
    t.integer "custom_field_key_id", null: false
    t.text "data"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "member_id", null: false
    t.index ["custom_field_key_id"], name: "index_custom_fields_on_custom_field_key_id"
    t.index ["data"], name: "index_custom_fields_on_data_gin", opclass: :gin_trgm_ops, using: :gin
    t.index ["member_id"], name: "index_custom_fields_on_member_id"
  end

  create_table "dataset_rows", id: :serial, force: :cascade do |t|
    t.integer "dataset_id", null: false
    t.text "link"
    t.text "key"
    t.text "value"
    t.index ["dataset_id"], name: "index_dataset_rows_on_dataset_id"
    t.index ["link"], name: "index_dataset_rows_on_link"
  end

  create_table "datasets", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "slug"
    t.text "link_relation"
    t.text "link_column"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "columns"
    t.text "file_path"
  end

  create_table "dedupe_blocks", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "block_key"
    t.index ["block_key"], name: "index_dedupe_blocks_on_block_key"
    t.index ["member_id"], name: "index_dedupe_blocks_on_member_id"
  end

  create_table "dedupe_index_data", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "middle_names"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.string "line1"
    t.string "line2"
    t.string "town"
    t.string "state"
    t.string "postcode"
    t.string "country"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at", precision: nil
    t.datetime "locked_at", precision: nil
    t.datetime "failed_at", precision: nil
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "demographic_attribute_values", force: :cascade do |t|
    t.string "demographic_item_type", null: false
    t.bigint "demographic_item_id", null: false, comment: "The demographic item which this value is linked to. This is a polymorphic reference, normally it would link to either a demographic_group or to a specific member."
    t.bigint "demographic_attribute_id", null: false
    t.string "qualifier", comment: "Optional qualifier for this demographic attribute value, eg. an \"age bracket probability\" row might have an age bracket as the qualifier, and a probability as the value."
    t.string "value", null: false, comment: "String representing the value of this demographic attribute - expected to represent the data class/type in the linked demographic_attribute.data_class"
    t.string "source", comment: "Optional source for where the information about the demographic group, member, etc came from"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["demographic_attribute_id"], name: "index_demographic_attribute_values_on_demographic_attribute_id"
    t.index ["demographic_item_type", "demographic_item_id", "demographic_attribute_id", "qualifier"], name: "idx_demographic_attribute_values_on_item_attribute_qualifier", unique: true, where: "(qualifier IS NOT NULL)"
    t.index ["demographic_item_type", "demographic_item_id", "demographic_attribute_id"], name: "idx_demographic_attribute_values_on_item_attribute", unique: true, where: "(qualifier IS NULL)"
    t.index ["demographic_item_type", "demographic_item_id"], name: "idx_demographic_attribute_values_on_demographic_item"
  end

  create_table "demographic_attributes", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", null: false
    t.string "data_class", comment: "The data class/type of this demographic attribute, eg. String, Percentage, etc"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_demographic_attributes_on_name", unique: true
  end

  create_table "demographic_groups", force: :cascade do |t|
    t.string "demographic_class", null: false, comment: "The class/type of this demographic group, eg. Experian UK Mosaic Type"
    t.string "name", null: false, comment: "The canonical name for the demographic group within this class, eg. A01"
    t.string "description", null: false, comment: "A description for this demographic group, eg. World-Class Wealth"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["demographic_class", "name"], name: "index_demographic_groups_on_demographic_class_and_name", unique: true
    t.index ["demographic_class"], name: "index_demographic_groups_on_demographic_class"
    t.index ["name"], name: "index_demographic_groups_on_name"
  end

  create_table "donations", id: :serial, force: :cascade do |t|
    t.integer "member_action_id"
    t.integer "member_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.text "external_source"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "external_id"
    t.text "nonce"
    t.string "medium"
    t.integer "regular_donation_id"
    t.datetime "refunded_at", precision: nil
    t.index ["medium", "external_id"], name: "index_donations_on_medium_and_external_id", unique: true, where: "((medium IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["member_action_id"], name: "index_donations_on_member_action_id"
    t.index ["member_id", "amount", "created_at"], name: "index_donations_on_member_id_and_amount_and_created_at", unique: true
    t.index ["member_id"], name: "index_donations_on_member_id"
    t.index ["nonce"], name: "index_donations_on_nonce"
  end

  create_table "event_rsvps", id: :serial, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.boolean "attended"
    t.json "data", default: "{}"
    t.index ["event_id"], name: "index_event_rsvps_on_event_id"
    t.index ["member_id"], name: "index_event_rsvps_on_member_id"
  end

  create_table "events", force: :cascade do |t|
    t.text "name"
    t.datetime "start_time", precision: nil
    t.datetime "end_time", precision: nil
    t.text "description"
    t.integer "campaign_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "host_id"
    t.integer "controlshift_event_id"
    t.text "location"
    t.float "latitude"
    t.float "longitude"
    t.integer "attendees"
    t.integer "group_id"
    t.integer "area_id"
    t.text "image_url"
    t.boolean "approved", default: false, null: false
    t.boolean "invite_only", default: false, null: false
    t.integer "max_attendees"
    t.integer "external_id"
    t.text "technical_type"
    t.string "system"
    t.string "subsystem"
    t.json "data", default: "{}"
    t.index ["area_id"], name: "index_events_on_area_id"
    t.index ["campaign_id"], name: "index_events_on_campaign_id"
    t.index ["external_id", "system", "subsystem"], name: "index_events_on_system", unique: true
    t.index ["external_id"], name: "index_events_on_external_id"
    t.index ["host_id"], name: "index_events_on_host_id"
    t.index ["technical_type"], name: "index_events_on_technical_type"
  end

  create_table "events_members", force: :cascade do |t|
    t.integer "event_id"
    t.integer "member_id"
  end

  create_table "failed_donations", force: :cascade do |t|
    t.string "medium"
    t.decimal "amount", precision: 10, scale: 2
    t.integer "regular_donation_id"
    t.integer "member_id"
    t.string "failure_reason"
    t.datetime "donation_date"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "first_names", id: :serial, force: :cascade do |t|
    t.text "first_name"
    t.string "gender"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "vocative"
  end

  create_table "flows", force: :cascade do |t|
    t.string "name"
    t.jsonb "external_systems_params", default: "{}"
    t.string "status", default: "initialising", null: false
    t.string "message"
    t.bigint "search_id"
    t.bigint "author_id"
    t.time "run_at"
    t.datetime "last_ran_at", precision: nil
    t.boolean "active", default: true
    t.integer "run_count", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_flows_on_author_id"
    t.index ["search_id"], name: "index_flows_on_search_id"
  end

  create_table "follow_ups", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "contactee_id", null: false
    t.text "title"
    t.text "description"
    t.datetime "contact_time", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["contactee_id"], name: "index_follow_ups_on_contactee_id"
    t.index ["member_id"], name: "index_follow_ups_on_member_id"
  end

  create_table "group_campaigns", id: :serial, force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "campaign_id", null: false
    t.text "notes"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["campaign_id"], name: "index_group_campaigns_on_campaign_id"
    t.index ["group_id"], name: "index_group_campaigns_on_group_id"
  end

  create_table "groups", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.integer "area_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "controlshift_group_id"
    t.text "group_type"
    t.integer "member_count"
    t.integer "activity_rating"
    t.text "key_issues"
    t.float "latitude"
    t.float "longitude"
    t.text "location"
    t.text "internal_notes"
    t.integer "event_count"
    t.text "image_url"
    t.text "controlshift_group_slug"
    t.index ["area_id"], name: "index_groups_on_area_id"
  end

  create_table "groups_members", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "membership_type"
    t.text "notes"
    t.datetime "deleted_at", precision: nil
    t.index ["group_id"], name: "index_groups_members_on_group_id"
    t.index ["member_id"], name: "index_groups_members_on_member_id"
  end

  create_table "issue_categories", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "issue_categories_issues", id: :serial, force: :cascade do |t|
    t.integer "issue_id", null: false
    t.integer "issue_category_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["issue_category_id"], name: "index_issue_categories_issues_on_issue_category_id"
    t.index ["issue_id"], name: "index_issue_categories_issues_on_issue_id"
  end

  create_table "issue_links", id: :serial, force: :cascade do |t|
    t.text "controlshift_tag", null: false
    t.integer "issue_id", null: false
    t.index ["issue_id"], name: "index_issue_links_on_issue_id"
  end

  create_table "issues", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "default"
  end

  create_table "journey_coordinators", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["journey_id"], name: "index_journey_coordinators_on_journey_id"
    t.index ["member_id"], name: "index_journey_coordinators_on_member_id"
  end

  create_table "journeys", force: :cascade do |t|
    t.text "name"
    t.json "steps"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "list_members", id: :serial, force: :cascade do |t|
    t.integer "list_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.index ["list_id"], name: "index_list_members_on_list_id"
    t.index ["member_id"], name: "index_list_members_on_member_id"
  end

  create_table "lists", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "member_count", default: 0, null: false
    t.boolean "synced_to_redshift", default: false, null: false
    t.boolean "permanent", default: false, null: false
    t.bigint "search_id"
    t.bigint "author_id"
    t.index ["author_id"], name: "index_lists_on_author_id"
    t.index ["permanent"], name: "index_lists_on_permanent"
    t.index ["search_id"], name: "index_lists_on_search_id"
    t.index ["synced_to_redshift"], name: "index_lists_on_synced_to_redshift"
  end

  create_table "locations", id: :serial, force: :cascade do |t|
    t.text "description"
    t.float "latitude"
    t.float "longitude"
    t.text "postcode"
    t.text "region"
    t.integer "controlshift_location_id"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "mailing_components", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "description"
    t.text "merge_tag"
    t.text "template"
    t.integer "mailing_id"
    t.boolean "global"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["mailing_id"], name: "index_mailing_components_on_mailing_id"
  end

  create_table "mailing_links", id: :serial, force: :cascade do |t|
    t.integer "mailing_id", null: false
    t.text "name"
    t.text "url"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "utm_source"
    t.text "utm_medium"
    t.text "utm_campaign"
    t.integer "total_clicks"
    t.index ["mailing_id", "url"], name: "index_mailing_links_on_mailing_id_and_url", using: :gin
    t.index ["mailing_id"], name: "index_mailing_links_on_mailing_id"
  end

  create_table "mailing_logs", force: :cascade do |t|
    t.bigint "mailing_id", null: false
    t.text "member_id"
    t.text "error"
    t.boolean "sent"
    t.boolean "invalid_domain"
    t.boolean "rejected"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "send_time"
    t.text "external_id"
    t.index ["external_id"], name: "index_mailing_logs_on_external_id"
    t.index ["mailing_id", "member_id", "sent"], name: "idx_mailing_logs_on_mailing_member_sent"
  end

  create_table "mailing_templates", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "header_html"
    t.text "footer_html"
    t.text "header_plain"
    t.text "footer_plain"
    t.boolean "default"
  end

  create_table "mailing_test_cases", id: :serial, force: :cascade do |t|
    t.integer "mailing_test_id", null: false
    t.text "template"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["mailing_test_id"], name: "index_mailing_test_cases_on_mailing_test_id"
  end

  create_table "mailing_tests", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "test_type"
    t.text "tags"
    t.text "description"
    t.text "merge_tag"
    t.integer "mailing_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["mailing_id"], name: "index_mailing_tests_on_mailing_id"
  end

  create_table "mailing_variation_test_cases", id: :serial, force: :cascade do |t|
    t.integer "mailing_variation_id", null: false
    t.integer "mailing_test_case_id", null: false
    t.index ["mailing_test_case_id"], name: "index_mailing_variation_test_cases_on_mailing_test_case_id"
    t.index ["mailing_variation_id"], name: "index_mailing_variation_test_cases_on_mailing_variation_id"
  end

  create_table "mailing_variations", id: :serial, force: :cascade do |t|
    t.integer "mailing_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "total_opens", default: 0, null: false
    t.integer "total_clicks", default: 0, null: false
    t.integer "total_members", default: 0, null: false
    t.integer "total_actions", default: 0, null: false
    t.decimal "donate_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "donate_count", default: 0, null: false
    t.decimal "reg_donate_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "reg_donate_count", default: 0, null: false
    t.index ["mailing_id"], name: "index_mailing_variations_on_mailing_id"
  end

  create_table "mailings", force: :cascade do |t|
    t.integer "external_id"
    t.text "name"
    t.text "subject"
    t.text "body_html"
    t.text "body_plain"
    t.text "from"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "recipients_synced"
    t.integer "member_count"
    t.text "parsed_html"
    t.integer "mailing_template_id"
    t.integer "list_id"
    t.float "send_time"
    t.datetime "prepared_send_at", precision: nil
    t.integer "total_opens", default: 0
    t.integer "total_clicks", default: 0
    t.text "from_name"
    t.text "from_email"
    t.integer "total_spam_reports", default: 0
    t.integer "total_bounces", default: 0
    t.datetime "finished_sending_at", precision: nil
    t.integer "total_unsubscribes", default: 0
    t.datetime "scheduled_for", precision: nil
    t.boolean "priority"
    t.integer "processed_count"
    t.boolean "aborted", default: false
    t.boolean "recurring", default: false
    t.integer "recurring_max_recipients_per_send"
    t.integer "search_id"
    t.integer "parent_mailing_id"
    t.text "body_markdown"
    t.text "recurring_schedule"
    t.time "recurring_at"
    t.integer "recurring_day"
    t.datetime "recurring_last_run_started", precision: nil
    t.boolean "paused", default: false
    t.boolean "is_controlled_externally", default: false, null: false
    t.string "external_slug"
    t.integer "total_actions", default: 0, null: false
    t.decimal "total_donate_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "total_donate_count", default: 0, null: false
    t.decimal "total_reg_donate_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "total_reg_donate_count", default: 0, null: false
    t.datetime "started_send_at", precision: nil
    t.integer "cloned_mailing_id"
    t.integer "prepared_count", default: 0, null: false
    t.text "reply_to"
    t.boolean "quiet_send", default: false, null: false
    t.text "renderer", default: "liquid", null: false
    t.text "archived_subject"
    t.text "archived_body"
    t.integer "campaign_id"
    t.index ["cloned_mailing_id"], name: "index_mailings_on_cloned_mailing_id"
    t.index ["list_id"], name: "index_mailings_on_list_id"
    t.index ["mailing_template_id"], name: "index_mailings_on_mailing_template_id"
    t.index ["parent_mailing_id"], name: "index_mailings_on_parent_mailing_id"
    t.index ["recurring"], name: "index_mailings_on_recurring"
  end

  create_table "member_action_consents", id: :serial, force: :cascade do |t|
    t.integer "member_action_id", null: false
    t.integer "consent_text_id", null: false
    t.integer "consent_level", null: false
    t.string "consent_method"
    t.string "consent_method_option"
    t.integer "parent_member_action_consent_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["consent_text_id"], name: "index_member_action_consents_on_consent_text_id"
    t.index ["member_action_id", "consent_text_id", "consent_level", "consent_method", "consent_method_option"], name: "idx_member_action_consents_on_member_action_and_consent_fields", unique: true
    t.index ["member_action_id"], name: "index_member_action_consents_on_member_action_id"
    t.index ["parent_member_action_consent_id"], name: "index_member_action_consents_on_parent_member_action_consent_id"
  end

  create_table "member_actions", force: :cascade do |t|
    t.integer "action_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.json "metadata"
    t.integer "source_id"
    t.index ["action_id"], name: "index_member_actions_on_action_id"
    t.index ["member_id", "source_id"], name: "index_member_actions_on_member_id_and_source_id"
    t.index ["source_id"], name: "index_member_actions_on_source_id"
  end

  create_table "member_actions_data", id: :serial, force: :cascade do |t|
    t.integer "member_action_id", null: false
    t.text "value"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "action_key_id", null: false
    t.index ["action_key_id"], name: "index_member_actions_data_on_action_key_id"
    t.index ["member_action_id"], name: "index_member_actions_data_on_member_action_id"
  end

  create_table "member_demographic_groups", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "demographic_group_id", null: false
    t.string "linked_via", null: false, comment: "The method used to link this member to this demographic group - eg. \"zip\" if the member is in this group because of the zip/postcode they live in"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["demographic_group_id"], name: "index_member_demographic_groups_on_demographic_group_id"
    t.index ["member_id", "demographic_group_id", "linked_via"], name: "idx_member_demographic_groups_on_member_group_via", unique: true
    t.index ["member_id"], name: "index_member_demographic_groups_on_member_id"
  end

  create_table "member_external_ids", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.string "system", null: false
    t.string "external_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id"], name: "index_member_external_ids_on_member_id"
    t.index ["system", "external_id"], name: "index_member_external_ids_on_system_and_external_id", unique: true
  end

  create_table "member_journeys", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "member_id", null: false
    t.integer "action_id"
    t.integer "current_step"
    t.json "step_history"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "complete"
    t.datetime "deleted_at", precision: nil
    t.index ["action_id"], name: "index_member_journeys_on_action_id"
    t.index ["current_step"], name: "index_member_journeys_on_current_step"
    t.index ["journey_id"], name: "index_member_journeys_on_journey_id"
    t.index ["member_id"], name: "index_member_journeys_on_member_id"
  end

  create_table "member_mailings", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "mailing_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "first_opened", precision: nil
    t.datetime "first_clicked", precision: nil
    t.text "guid"
    t.integer "mailing_variation_id"
    t.index ["guid"], name: "index_member_mailings_on_guid"
    t.index ["mailing_id", "first_clicked"], name: "index_member_mailings_on_mailing_id_and_first_clicked"
    t.index ["mailing_id", "first_opened"], name: "index_member_mailings_on_mailing_id_and_first_opened"
    t.index ["mailing_variation_id", "first_clicked"], name: "index_member_mailings_on_mailing_variation_id_and_first_clicked"
    t.index ["mailing_variation_id", "first_opened"], name: "index_member_mailings_on_mailing_variation_id_and_first_opened"
    t.index ["member_id"], name: "index_member_mailings_on_member_id"
  end

  create_table "member_merge_logs", id: :serial, force: :cascade do |t|
    t.integer "old_member_id"
    t.integer "new_member_id"
    t.text "email_address"
    t.text "serialized_old_record"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "member_notifications", id: :serial, force: :cascade do |t|
    t.integer "notification_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "opened"
    t.index ["member_id"], name: "index_member_notifications_on_member_id"
    t.index ["notification_id"], name: "index_member_notifications_on_notification_id"
  end

  create_table "member_open_click_rate", id: false, force: :cascade do |t|
    t.integer "member_id", null: false
    t.float "open_rate", null: false
    t.float "click_rate", default: 0.0, null: false
    t.index ["click_rate"], name: "index_member_open_click_rate_on_click_rate"
    t.index ["member_id"], name: "index_member_open_click_rate_on_member_id", unique: true
    t.index ["open_rate"], name: "index_member_open_click_rate_on_open_rate"
  end

  create_table "member_resources", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "resource_id", null: false
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id", "resource_id"], name: "index_member_resources_on_member_id_and_resource_id", unique: true
    t.index ["member_id"], name: "index_member_resources_on_member_id"
    t.index ["resource_id"], name: "index_member_resources_on_resource_id"
  end

  create_table "member_skills", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "skill_id", null: false
    t.integer "rating"
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id", "skill_id"], name: "index_member_skills_on_member_id_and_skill_id", unique: true
    t.index ["member_id"], name: "index_member_skills_on_member_id"
    t.index ["skill_id"], name: "index_member_skills_on_skill_id"
  end

  create_table "member_stages", force: :cascade do |t|
    t.text "name"
    t.integer "stage_id", null: false
    t.integer "member_id", null: false
    t.integer "user_id"
    t.boolean "progressed"
    t.boolean "dropped"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "editing_locked"
    t.json "notes"
    t.datetime "deleted_at", precision: nil
    t.index ["member_id"], name: "index_member_stages_on_member_id"
    t.index ["stage_id"], name: "index_member_stages_on_stage_id"
  end

  create_table "member_subscription_events", force: :cascade do |t|
    t.string "action", null: false
    t.string "operation", null: false
    t.string "operation_reason", default: "not_specified"
    t.boolean "operation_permanently_deferred", default: false
    t.bigint "member_subscription_id"
    t.integer "subscribable_id"
    t.string "subscribable_type"
    t.boolean "subscription_status_changed"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["member_subscription_id", "operation"], name: "index_member_subscription_events_member_subscription_operation"
    t.index ["member_subscription_id"], name: "index_member_subscription_events_on_member_subscription_id"
    t.index ["subscribable_type", "subscribable_id", "operation"], name: "index_member_subscription_events_subscribable_operation"
    t.index ["subscribable_type", "subscribable_id"], name: "index_member_subscription_events_subscribable"
  end

  create_table "member_subscription_logs", id: :serial, force: :cascade do |t|
    t.integer "member_id"
    t.integer "subscription_id"
    t.text "operation"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "dyno"
    t.text "unsubscribe_reason"
    t.text "backtrace"
  end

  create_table "member_subscriptions", id: :serial, force: :cascade do |t|
    t.integer "subscription_id", null: false
    t.integer "member_id", null: false
    t.datetime "unsubscribed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "unsubscribe_reason"
    t.boolean "permanent"
    t.integer "unsubscribe_mailing_id"
    t.string "subscribe_reason"
    t.datetime "subscribed_at", precision: nil
    t.index ["member_id", "subscription_id"], name: "index_member_subscriptions_on_member_id_and_subscription_id", unique: true
    t.index ["member_id"], name: "index_member_subscriptions_on_member_id"
    t.index ["subscription_id"], name: "index_member_subscriptions_on_subscription_id"
    t.index ["unsubscribe_mailing_id"], name: "index_member_subscriptions_on_unsubscribe_mailing_id"
    t.index ["unsubscribed_at"], name: "index_member_subscriptions_on_unsubscribed_at"
  end

  create_table "member_top_issues", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "issue_id", null: false
    t.index ["issue_id"], name: "index_member_top_issues_on_issue_id"
    t.index ["member_id"], name: "index_member_top_issues_on_member_id", unique: true
  end

  create_table "member_volunteer_tasks", force: :cascade do |t|
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "volunteer_task_id", null: false
    t.index ["member_id"], name: "index_member_volunteer_tasks_on_member_id"
    t.index ["volunteer_task_id"], name: "index_member_volunteer_tasks_on_volunteer_task_id"
  end

  create_table "members", force: :cascade do |t|
    t.text "email"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "joined_at", precision: nil
    t.text "crypted_password"
    t.text "guid"
    t.json "action_history"
    t.text "reset_token"
    t.integer "authy_id"
    t.integer "role_id"
    t.datetime "last_donated", precision: nil
    t.integer "donations_count"
    t.float "average_donation"
    t.float "highest_donation"
    t.text "mosaic_group"
    t.text "mosaic_code"
    t.text "entry_point"
    t.float "latitude"
    t.float "longitude"
    t.string "email_sha256"
    t.text "first_name"
    t.text "middle_names"
    t.text "last_name"
    t.string "title"
    t.string "gender"
    t.string "donation_preference", limit: 20
    t.index "btrim(((COALESCE(first_name, ''::text) || ' '::text) || COALESCE(last_name, ''::text))) gin_trgm_ops", name: "index_members_on_full_name_gin", using: :gin
    t.index ["email"], name: "index_members_on_email"
    t.index ["email"], name: "index_members_on_email_gin", opclass: :gin_trgm_ops, using: :gin
    t.index ["first_name"], name: "index_members_on_first_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["guid"], name: "index_members_on_guid", unique: true
    t.index ["last_name"], name: "index_members_on_last_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["middle_names"], name: "index_members_on_middle_names", opclass: :gin_trgm_ops, using: :gin
    t.index ["role_id"], name: "index_members_on_role_id"
    t.index ["updated_at"], name: "index_members_on_updated_at"
  end

  create_table "members_on_ice", id: false, force: :cascade do |t|
    t.integer "member_id", null: false
    t.index ["member_id"], name: "index_members_on_ice_on_member_id", unique: true
  end

  create_table "members_on_ice_exclusions", force: :cascade do |t|
    t.integer "member_id", null: false
    t.index ["member_id"], name: "index_members_on_ice_exclusions_on_member_id", unique: true
  end

  create_table "mosaic", id: :serial, force: :cascade do |t|
    t.text "postcode"
    t.text "mosaic_group"
    t.text "code"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "mosaic_attribute_values", id: :serial, force: :cascade do |t|
    t.integer "mosaic_attribute_id"
    t.text "mosaic_code"
    t.float "value"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "mosaic_attributes", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "slug"
    t.text "description"
    t.float "national_mean"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "note_types", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "user_selectable"
  end

  create_table "notes", force: :cascade do |t|
    t.integer "note_type_id", null: false
    t.integer "user_id", null: false
    t.integer "member_id", null: false
    t.text "text"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id"], name: "index_notes_on_member_id"
    t.index ["note_type_id"], name: "index_notes_on_note_type_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notification_endpoints", id: :serial, force: :cascade do |t|
    t.string "endpoint"
    t.string "p256dh"
    t.string "auth"
    t.integer "member_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id"], name: "index_notification_endpoints_on_member_id"
  end

  create_table "notification_links", id: :serial, force: :cascade do |t|
    t.integer "member_notification_id", null: false
    t.string "guid"
    t.string "redirect_url"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_notification_id"], name: "index_notification_links_on_member_notification_id"
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.string "url"
    t.string "image"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "list_id"
    t.datetime "sent_at", precision: nil
    t.datetime "finished_sending_at", precision: nil
    t.integer "total_clicks"
    t.integer "total_unsubscribes"
    t.index ["list_id"], name: "index_notifications_on_list_id"
  end

  create_table "one_month_actives", id: false, force: :cascade do |t|
    t.integer "member_id", null: false
    t.index ["member_id"], name: "index_one_month_actives_on_member_id", unique: true
  end

  create_table "opens", force: :cascade do |t|
    t.integer "member_mailing_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "ip_address"
    t.text "user_agent"
    t.index ["member_mailing_id"], name: "index_opens_on_member_mailing_id"
  end

  create_table "organisation_memberships", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "organisation_id", null: false
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["member_id", "organisation_id"], name: "index_organisation_memberships_on_member_id_and_organisation_id", unique: true
    t.index ["member_id"], name: "index_organisation_memberships_on_member_id"
    t.index ["organisation_id"], name: "index_organisation_memberships_on_organisation_id"
  end

  create_table "organisations", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "parent_organisation_id"
    t.string "type"
    t.string "registered_name"
    t.string "company_number"
    t.string "company_registrar"
    t.text "registry_url"
    t.text "address"
    t.text "website_url"
    t.integer "employees"
    t.integer "turnover"
    t.index ["parent_organisation_id"], name: "index_organisations_on_parent_organisation_id"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.text "permission_slug"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "phone_circles", force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "phone", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "phone_type"
    t.bigint "phone_circle_id"
    t.string "do_not_disturb"
    t.index ["member_id"], name: "index_phone_numbers_on_member_id"
    t.index ["phone"], name: "index_phone_numbers_on_phone"
    t.index ["phone_circle_id"], name: "index_phone_numbers_on_phone_circle_id"
  end

  create_table "post_consent_methods", force: :cascade do |t|
    t.bigint "consent_text_id", null: false
    t.integer "min_consent_level", null: false
    t.integer "max_consent_level", null: false
    t.string "method", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "subscription_id"
    t.index ["consent_text_id"], name: "index_post_consent_methods_on_consent_text_id"
    t.index ["subscription_id"], name: "index_post_consent_methods_on_subscription_id"
  end

  create_table "postcodes", id: :serial, force: :cascade do |t|
    t.string "zip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.float "latitude"
    t.float "longitude"
    t.index ["zip"], name: "index_postcodes_on_zip"
  end

  create_table "questions", id: :serial, force: :cascade do |t|
    t.integer "action_key_id", null: false
    t.string "question_type", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["action_key_id"], name: "index_questions_on_action_key_id"
  end

  create_table "regular_donations", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.datetime "started_at", precision: nil
    t.datetime "ended_at", precision: nil
    t.text "frequency"
    t.text "medium"
    t.text "source"
    t.decimal "initial_amount", precision: 10, scale: 2
    t.decimal "current_amount", precision: 10, scale: 2
    t.datetime "amount_last_changed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "smartdebit_reference"
    t.string "external_id"
    t.datetime "payment_method_expires_at", precision: nil
    t.text "ended_reason"
    t.bigint "member_action_id"
    t.index ["medium", "external_id"], name: "index_regular_donations_on_medium_and_external_id", unique: true, where: "((medium IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["member_action_id"], name: "index_regular_donations_on_member_action_id"
    t.index ["member_id"], name: "index_regular_donations_on_member_id"
  end

  create_table "resources", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "role_permissions", id: :serial, force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "permission_id", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.integer "role_id"
    t.text "description"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "super_admin", default: false, null: false
    t.boolean "send_sms", default: false, null: false
    t.boolean "manage_members", default: false, null: false
    t.boolean "imports", default: false, null: false
    t.boolean "manage_variables", default: false, null: false
    t.boolean "read_mailings", default: false, null: false
    t.boolean "send_mailings", default: false, null: false
    t.boolean "plivo_webhook", default: false, null: false
    t.boolean "twilio_webhook", default: false, null: false
    t.boolean "nexmo_webhook", default: false, null: false
    t.boolean "paypal_webhook", default: false, null: false
    t.boolean "go_cardless_webhook", default: false, null: false
    t.boolean "stripe_webhook", default: false, null: false
    t.boolean "razorpay_webhook", default: false, null: false
    t.boolean "csl_webhook", default: false, null: false
    t.boolean "lists_api", default: false, null: false
    t.boolean "searches_api", default: false, null: false
    t.boolean "groups_api", default: false, null: false
    t.boolean "members_api", default: false, null: false
    t.boolean "member_subscriptions_api", default: false, null: false
    t.boolean "donations_api", default: false, null: false
    t.boolean "events_api", default: false, null: false
    t.boolean "actions_api", default: false, null: false
    t.boolean "mailjet_api", default: false, null: false
    t.boolean "mailings_api", default: false, null: false
    t.boolean "sms", default: false, null: false
    t.boolean "view_members", default: false, null: false
    t.boolean "update_member_details", default: false, null: false
    t.boolean "update_member_subscriptions", default: false, null: false
    t.boolean "anonymize_members", default: false, null: false
    t.boolean "bulk_update_members", default: false, null: false
    t.boolean "push_members_to_service", default: false, null: false
    t.boolean "manage_searches", default: false, null: false
    t.boolean "upload_lists", default: false, null: false
    t.boolean "read_lists", default: false, null: false
    t.boolean "download_lists", default: false, null: false
    t.boolean "anonymize_lists", default: false, null: false
    t.boolean "view_job_status", default: false, null: false
  end

  create_table "searches", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "name", null: false
    t.boolean "complete"
    t.text "member_ids"
    t.integer "total_members"
    t.integer "offset"
    t.integer "count"
    t.integer "page"
    t.text "rules"
    t.text "sql"
    t.boolean "pinned", default: false, null: false
    t.boolean "permanent", default: false, null: false
    t.bigint "author_id"
    t.text "description"
    t.datetime "started_running_at", precision: nil
    t.index ["author_id"], name: "index_searches_on_author_id"
    t.index ["permanent"], name: "index_searches_on_permanent"
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "skills", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "smses", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.boolean "inbound", default: false, null: false
    t.text "from_number"
    t.text "to_number"
    t.text "body"
    t.text "guid"
    t.string "status"
    t.integer "text_blast_id"
    t.datetime "clicked_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "external_id"
    t.index ["member_id"], name: "index_smses_on_member_id"
    t.index ["text_blast_id"], name: "index_smses_on_text_blast_id"
  end

  create_table "sources", id: :serial, force: :cascade do |t|
    t.text "medium", default: "default", null: false
    t.text "source", default: "default", null: false
    t.text "campaign", default: "unknown", null: false
    t.float "amount_spent"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "mailing_id"
    t.index ["campaign"], name: "index_sources_on_campaign"
    t.index ["mailing_id"], name: "index_sources_on_mailing_id"
    t.index ["medium"], name: "index_sources_on_medium"
    t.index ["source", "medium", "campaign"], name: "index_sources_on_source_and_medium_and_campaign", unique: true
    t.index ["source"], name: "index_sources_on_source"
  end

  create_table "spam_exclude", id: false, force: :cascade do |t|
    t.integer "member_id", null: false
    t.index ["member_id"], name: "index_spam_exclude_on_member_id", unique: true
  end

  create_table "spam_exclude_rules", force: :cascade do |t|
    t.text "domain", null: false
    t.float "days_until_excluded", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["domain"], name: "index_spam_exclude_rules_on_domain", unique: true
  end

  create_table "stages", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.integer "next_stage_id"
    t.integer "journey_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "show_local_events"
    t.text "advance_button_text"
    t.text "drop_button_text"
    t.text "script"
    t.index ["journey_id"], name: "index_stages_on_journey_id"
    t.index ["next_stage_id"], name: "index_stages_on_next_stage_id"
  end

  create_table "subscriptions", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "description"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "member_count", default: 0
    t.string "slug", null: false
    t.boolean "is_default", default: false, null: false
    t.index ["slug"], name: "index_subscriptions_on_slug", unique: true
  end

  create_table "syncs", force: :cascade do |t|
    t.string "external_system", null: false
    t.string "external_system_params"
    t.string "sync_type", null: false
    t.string "status", default: "initialising", null: false
    t.integer "imported_member_count", default: 0, null: false
    t.integer "progress", default: 0, null: false
    t.string "message"
    t.bigint "list_id"
    t.bigint "contact_campaign_id"
    t.bigint "author_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "records_for_import_scope"
    t.text "pull_deferred"
    t.text "records_for_import"
    t.index ["author_id"], name: "index_syncs_on_author_id"
    t.index ["contact_campaign_id"], name: "index_syncs_on_contact_campaign_id"
    t.index ["list_id"], name: "index_syncs_on_list_id"
  end

  create_table "text_blast_links", id: :serial, force: :cascade do |t|
    t.integer "text_blast_id", null: false
    t.text "url"
    t.text "short_link"
    t.integer "total_clicks"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["text_blast_id"], name: "index_text_blast_links_on_text_blast_id"
  end

  create_table "text_blasts", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "body"
    t.integer "list_id"
    t.datetime "sent_at", precision: nil
    t.datetime "finished_sending_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "direct_communication"
    t.integer "total_clicks"
    t.integer "total_bounces"
    t.integer "total_unsubscribes"
    t.integer "parent_inbound_text_id"
    t.datetime "scheduled_for", precision: nil
    t.integer "member_count"
    t.index ["list_id"], name: "index_text_blasts_on_list_id"
  end

  create_table "three_month_actives", id: false, force: :cascade do |t|
    t.integer "member_id", null: false
    t.index ["member_id"], name: "index_three_month_actives_on_member_id", unique: true
  end

  create_table "unsubscribe_attempt_logs", force: :cascade do |t|
    t.bigint "subscription_id"
    t.string "method"
    t.string "recipient_handle"
    t.string "submitted_handle"
    t.boolean "success"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "variables", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "value"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "volunteering_tasks", force: :cascade do |t|
    t.integer "stage_id"
    t.text "title"
    t.text "description"
    t.datetime "ends_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "zip_demographic_groups", force: :cascade do |t|
    t.string "zip", null: false
    t.bigint "demographic_group_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["demographic_group_id"], name: "index_zip_demographic_groups_on_demographic_group_id"
    t.index ["zip", "demographic_group_id"], name: "index_zip_demographic_groups_on_zip_and_demographic_group_id", unique: true
    t.index ["zip"], name: "index_zip_demographic_groups_on_zip"
  end

  create_table "zips", force: :cascade do |t|
    t.text "zip"
    t.text "county"
    t.text "lau"
    t.text "pcon_new"
    t.integer "eer"
    t.float "latitude"
    t.float "longitude"
    t.text "ccg"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  add_foreign_key "action_keys", "actions"
  add_foreign_key "actions", "campaigns"
  add_foreign_key "actions_mailings", "actions"
  add_foreign_key "actions_mailings", "mailings"
  add_foreign_key "addresses", "canonical_addresses"
  add_foreign_key "addresses", "members"
  add_foreign_key "api_users", "roles"
  add_foreign_key "area_memberships", "areas"
  add_foreign_key "area_memberships", "members"
  add_foreign_key "area_zips", "areas"
  add_foreign_key "areas_canonical_addresses", "areas"
  add_foreign_key "areas_canonical_addresses", "canonical_addresses"
  add_foreign_key "audits", "members"
  add_foreign_key "campaigns", "issues"
  add_foreign_key "campaigns", "members", column: "author_id"
  add_foreign_key "clicks", "mailing_links", column: "link_id"
  add_foreign_key "clicks", "member_mailings"
  add_foreign_key "conditional_list_members", "conditional_lists"
  add_foreign_key "conditional_list_members", "members"
  add_foreign_key "contact_response_keys", "contact_campaigns"
  add_foreign_key "contact_responses", "contact_response_keys"
  add_foreign_key "contact_responses", "contacts"
  add_foreign_key "contacts", "contact_campaigns"
  add_foreign_key "contacts", "members", column: "contactee_id"
  add_foreign_key "contacts", "members", column: "contactor_id"
  add_foreign_key "controlshift_consent_mappings", "consent_texts"
  add_foreign_key "controlshift_consent_mappings", "controlshift_consents"
  add_foreign_key "custom_fields", "custom_field_keys"
  add_foreign_key "custom_fields", "members"
  add_foreign_key "dataset_rows", "datasets"
  add_foreign_key "dedupe_blocks", "members"
  add_foreign_key "donations", "member_actions"
  add_foreign_key "donations", "members"
  add_foreign_key "donations", "regular_donations"
  add_foreign_key "event_rsvps", "events"
  add_foreign_key "event_rsvps", "members"
  add_foreign_key "events", "areas"
  add_foreign_key "events", "campaigns"
  add_foreign_key "events", "members", column: "host_id"
  add_foreign_key "failed_donations", "members"
  add_foreign_key "failed_donations", "regular_donations"
  add_foreign_key "flows", "members", column: "author_id"
  add_foreign_key "flows", "searches"
  add_foreign_key "follow_ups", "members"
  add_foreign_key "follow_ups", "members", column: "contactee_id"
  add_foreign_key "group_campaigns", "campaigns"
  add_foreign_key "group_campaigns", "groups"
  add_foreign_key "groups", "areas"
  add_foreign_key "groups_members", "groups"
  add_foreign_key "groups_members", "members"
  add_foreign_key "issue_categories_issues", "issue_categories"
  add_foreign_key "issue_categories_issues", "issues"
  add_foreign_key "issue_links", "issues"
  add_foreign_key "journey_coordinators", "journeys"
  add_foreign_key "journey_coordinators", "members"
  add_foreign_key "list_members", "lists"
  add_foreign_key "list_members", "members"
  add_foreign_key "lists", "members", column: "author_id"
  add_foreign_key "lists", "searches"
  add_foreign_key "mailing_components", "mailings"
  add_foreign_key "mailing_links", "mailings"
  add_foreign_key "mailing_logs", "mailings"
  add_foreign_key "mailing_test_cases", "mailing_tests"
  add_foreign_key "mailing_tests", "mailings"
  add_foreign_key "mailing_variation_test_cases", "mailing_test_cases"
  add_foreign_key "mailing_variation_test_cases", "mailing_variations"
  add_foreign_key "mailing_variations", "mailings"
  add_foreign_key "mailings", "lists"
  add_foreign_key "mailings", "mailing_templates"
  add_foreign_key "mailings", "mailings", column: "cloned_mailing_id"
  add_foreign_key "mailings", "mailings", column: "parent_mailing_id"
  add_foreign_key "member_action_consents", "consent_texts"
  add_foreign_key "member_action_consents", "member_action_consents", column: "parent_member_action_consent_id"
  add_foreign_key "member_action_consents", "member_actions"
  add_foreign_key "member_actions", "actions"
  add_foreign_key "member_actions", "members"
  add_foreign_key "member_actions", "sources"
  add_foreign_key "member_actions_data", "action_keys"
  add_foreign_key "member_actions_data", "member_actions"
  add_foreign_key "member_external_ids", "members"
  add_foreign_key "member_journeys", "journeys"
  add_foreign_key "member_journeys", "members"
  add_foreign_key "member_mailings", "mailing_variations"
  add_foreign_key "member_mailings", "mailings"
  add_foreign_key "member_mailings", "members"
  add_foreign_key "member_notifications", "members"
  add_foreign_key "member_notifications", "notifications"
  add_foreign_key "member_open_click_rate", "members"
  add_foreign_key "member_resources", "members"
  add_foreign_key "member_resources", "resources"
  add_foreign_key "member_skills", "members"
  add_foreign_key "member_skills", "skills"
  add_foreign_key "member_stages", "members"
  add_foreign_key "member_stages", "stages"
  add_foreign_key "member_subscriptions", "mailings", column: "unsubscribe_mailing_id"
  add_foreign_key "member_subscriptions", "members"
  add_foreign_key "member_subscriptions", "subscriptions"
  add_foreign_key "member_top_issues", "issues"
  add_foreign_key "member_top_issues", "members"
  add_foreign_key "member_volunteer_tasks", "members"
  add_foreign_key "member_volunteer_tasks", "volunteering_tasks", column: "volunteer_task_id"
  add_foreign_key "members", "roles"
  add_foreign_key "members_on_ice", "members"
  add_foreign_key "members_on_ice_exclusions", "members"
  add_foreign_key "notes", "members"
  add_foreign_key "notes", "members", column: "user_id"
  add_foreign_key "notes", "note_types"
  add_foreign_key "notification_endpoints", "members"
  add_foreign_key "notification_links", "member_notifications"
  add_foreign_key "notifications", "lists"
  add_foreign_key "opens", "member_mailings"
  add_foreign_key "organisation_memberships", "members"
  add_foreign_key "organisation_memberships", "organisations"
  add_foreign_key "organisations", "organisations", column: "parent_organisation_id"
  add_foreign_key "phone_numbers", "members"
  add_foreign_key "phone_numbers", "phone_circles"
  add_foreign_key "post_consent_methods", "consent_texts"
  add_foreign_key "post_consent_methods", "subscriptions"
  add_foreign_key "questions", "action_keys"
  add_foreign_key "regular_donations", "member_actions"
  add_foreign_key "regular_donations", "members"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "searches", "members", column: "author_id"
  add_foreign_key "smses", "members"
  add_foreign_key "smses", "text_blasts"
  add_foreign_key "sources", "mailings"
  add_foreign_key "spam_exclude", "members"
  add_foreign_key "stages", "journeys"
  add_foreign_key "stages", "stages", column: "next_stage_id"
  add_foreign_key "syncs", "contact_campaigns"
  add_foreign_key "syncs", "lists"
  add_foreign_key "syncs", "members", column: "author_id"
  add_foreign_key "text_blast_links", "text_blasts"
  add_foreign_key "text_blasts", "lists"

end
