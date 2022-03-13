# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "btree_gist"
  enable_extension "intarray"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "line1"
    t.text "line2"
    t.text "town"
    t.text "postcode"
    t.text "country"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "canonical_address_id"
    t.string "state"
    t.index ["canonical_address_id"], name: "index_addresses_on_canonical_address_id"
    t.index ["member_id"], name: "index_addresses_on_member_id"
  end

  create_table "anonymization_log", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.text "reason", null: false
    t.json "external_ids"
    t.datetime "anonymization_started_at", null: false
    t.datetime "anonymization_finished_at"
    t.index ["member_id"], name: "index_anonymization_log_on_member_id"
  end

  create_table "area_memberships", force: :cascade do |t|
    t.integer "area_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["area_id"], name: "index_area_memberships_on_area_id"
    t.index ["member_id"], name: "index_area_memberships_on_member_id"
  end

  create_table "areas", force: :cascade do |t|
    t.text "name"
    t.text "code"
    t.integer "mapit"
    t.text "area_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "party"
    t.text "runner_up_party"
    t.integer "majority"
    t.integer "vote_count"
    t.text "representative_name"
    t.text "representative_gender"
    t.string "representative_identifier"
  end

  create_table "contact_campaigns", id: :serial, force: :cascade do |t|
    t.text "name"
    t.integer "external_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "system"
    t.string "contact_type"
  end

  create_table "contact_response_keys", id: :serial, force: :cascade do |t|
    t.integer "contact_campaign_id"
    t.string "key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["contact_campaign_id"], name: "index_contact_response_keys_on_contact_campaign_id"
  end

  create_table "contact_responses", id: :serial, force: :cascade do |t|
    t.integer "contact_id", null: false
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
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
    t.datetime "happened_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.json "data", default: "{}"
    t.index ["contact_campaign_id"], name: "index_contacts_on_contact_campaign_id"
    t.index ["contact_type"], name: "index_contacts_on_contact_type"
    t.index ["contactee_id"], name: "index_contacts_on_contactee_id"
    t.index ["contactor_id"], name: "index_contacts_on_contactor_id"
    t.index ["external_id"], name: "index_contacts_on_external_id"
  end

  create_table "custom_field_keys", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "read_only", default: false, null: false
    t.boolean "categorical", default: false, null: false
    t.string "categories", default: [], array: true
    t.index ["name"], name: "index_custom_field_keys_on_name"
  end

  create_table "custom_fields", id: :serial, force: :cascade do |t|
    t.integer "custom_field_key_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "member_id", null: false
    t.index ["custom_field_key_id"], name: "index_custom_fields_on_custom_field_key_id"
    t.index ["member_id"], name: "index_custom_fields_on_member_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "event_rsvps", id: :serial, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.boolean "attended"
    t.json "data", default: "{}"
    t.index ["event_id"], name: "index_event_rsvps_on_event_id"
    t.index ["member_id"], name: "index_event_rsvps_on_member_id"
  end

  create_table "events", force: :cascade do |t|
    t.text "name"
    t.datetime "start_time"
    t.datetime "end_time"
    t.text "description"
    t.integer "campaign_id"
    t.datetime "created_at"
    t.datetime "updated_at"
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
    t.index ["external_id", "system", "subsystem"], name: "index_events_on_external_source", unique: true
    t.index ["external_id"], name: "index_events_on_external_id"
    t.index ["host_id"], name: "index_events_on_host_id"
    t.index ["technical_type"], name: "index_events_on_technical_type"
  end

  create_table "events_members", force: :cascade do |t|
    t.integer "event_id"
    t.integer "member_id"
  end

  create_table "list_members", id: :serial, force: :cascade do |t|
    t.integer "list_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.index ["list_id"], name: "index_list_members_on_list_id"
    t.index ["member_id"], name: "index_list_members_on_member_id"
  end

  create_table "lists", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "member_count", default: 0, null: false
    t.boolean "synced_to_redshift", default: false, null: false
    t.bigint "search_id"
    t.index ["search_id"], name: "index_lists_on_search_id"
    t.index ["synced_to_redshift"], name: "index_lists_on_synced_to_redshift"
  end

  create_table "member_external_ids", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.string "system", null: false
    t.string "external_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["member_id"], name: "index_member_external_ids_on_member_id"
    t.index ["system", "external_id"], name: "index_member_external_ids_on_system_and_external_id", unique: true
  end

  create_table "member_subscriptions", id: :serial, force: :cascade do |t|
    t.integer "subscription_id", null: false
    t.integer "member_id", null: false
    t.datetime "unsubscribed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "unsubscribe_reason"
    t.boolean "permanent"
    t.integer "unsubscribe_mailing_id"
    t.string "subscribe_reason"
    t.datetime "subscribed_at"
    t.index ["member_id", "subscription_id"], name: "index_member_subscriptions_on_member_id_and_subscription_id", unique: true
    t.index ["member_id"], name: "index_member_subscriptions_on_member_id"
    t.index ["subscription_id"], name: "index_member_subscriptions_on_subscription_id"
    t.index ["unsubscribe_mailing_id"], name: "index_member_subscriptions_on_unsubscribe_mailing_id"
    t.index ["unsubscribed_at"], name: "index_member_subscriptions_on_unsubscribed_at"
  end

  create_table "members", force: :cascade do |t|
    t.integer "cons_id"
    t.text "email"
    t.json "contact"
    t.json "meta"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "joined_at"
    t.text "crypted_password"
    t.text "guid"
    t.json "action_history"
    t.text "reset_token"
    t.integer "authy_id"
    t.integer "point_person_id"
    t.integer "role_id"
    t.datetime "last_donated"
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
    t.index ["email"], name: "index_members_on_email"
    t.index ["first_name"], name: "index_members_on_first_name"
    t.index ["last_name"], name: "index_members_on_last_name"
    t.index ["point_person_id"], name: "index_members_on_point_person_id"
    t.index ["role_id"], name: "index_members_on_role_id"
  end

  create_table "organisation_memberships", force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "organisation_id", null: false
    t.text "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["member_id"], name: "index_organisation_memberships_on_member_id"
    t.index ["organisation_id"], name: "index_organisation_memberships_on_organisation_id"
  end

  create_table "organisations", force: :cascade do |t|
    t.text "name"
    t.text "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.text "permission_slug"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "phone", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "phone_type"
    t.index ["member_id"], name: "index_phone_numbers_on_member_id"
    t.index ["phone"], name: "index_phone_numbers_on_phone"
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
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "searches", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "name"
    t.boolean "complete"
    t.text "member_ids"
    t.integer "total_members"
    t.integer "offset"
    t.integer "count"
    t.integer "page"
    t.text "rules"
    t.text "sql"
    t.boolean "pinned", default: false, null: false
  end

  create_table "subscriptions", id: :serial, force: :cascade do |t|
    t.text "name"
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "member_count", default: 0
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
    t.json "reference_data", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_syncs_on_author_id"
    t.index ["contact_campaign_id"], name: "index_syncs_on_contact_campaign_id"
    t.index ["list_id"], name: "index_syncs_on_list_id"
  end

end
