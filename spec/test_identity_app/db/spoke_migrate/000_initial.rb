class Initial < ActiveRecord::Migration[7.0]

  create_table "assignment", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "campaign_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "max_contacts"
    t.index ["campaign_id"], name: "assignment_campaign_id_index"
    t.index ["user_id"], name: "assignment_user_id_index"
  end

  create_table "assignment_feedback", id: :serial, force: :cascade do |t|
    t.integer "assignment_id", null: false
    t.integer "creator_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.jsonb "feedback"
    t.boolean "is_acknowledged", default: false
    t.boolean "complete", default: false
    t.index ["assignment_id"], name: "assignment_feedback_assignment_id_unique", unique: true
  end

  create_table "campaign", id: :serial, force: :cascade do |t|
    t.integer "organization_id", null: false
    t.text "title", default: "", null: false
    t.text "description", default: "", null: false
    t.boolean "is_started"
    t.datetime "due_by"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.boolean "is_archived"
    t.boolean "use_dynamic_assignment"
    t.text "logo_image_url"
    t.text "intro_html"
    t.text "primary_color"
    t.boolean "override_organization_texting_hours", default: false
    t.boolean "texting_hours_enforced", default: true
    t.integer "texting_hours_start", default: 9
    t.integer "texting_hours_end", default: 21
    t.text "timezone", default: "US/Eastern"
    t.integer "creator_id"
    t.string "messageservice_sid", limit: 255
    t.boolean "use_own_messaging_service", default: false
    t.text "join_token"
    t.integer "batch_size"
    t.json "features"
    t.float "response_window"
    t.index ["creator_id"], name: "campaign_creator_id_index"
    t.index ["organization_id"], name: "campaign_organization_id_index"
  end

  create_table "campaign_admin", id: :serial, force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.text "ingest_method"
    t.text "ingest_data_reference"
    t.text "ingest_result"
    t.boolean "ingest_success"
    t.integer "contacts_count"
    t.integer "deleted_optouts_count"
    t.integer "duplicate_contacts_count"
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["campaign_id"], name: "campaign_admin_campaign_id_index"
  end

  create_table "campaign_contact", id: :serial, force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "assignment_id"
    t.text "external_id", default: "", null: false
    t.text "first_name", default: "", null: false
    t.text "last_name", default: "", null: false
    t.text "cell", null: false
    t.text "zip", default: "", null: false
    t.text "custom_fields", default: "{}", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "message_status", default: "needsMessage", null: false
    t.boolean "is_opted_out", default: false
    t.text "timezone_offset", default: ""
    t.integer "error_code"
    t.index ["assignment_id", "timezone_offset"], name: "campaign_contact_assignment_id_timezone_offset_index"
    t.index ["campaign_id", "assignment_id"], name: "campaign_contact_campaign_id_assignment_id_index"
    t.index ["cell"], name: "campaign_contact_cell_index"
    t.check_constraint "message_status = ANY (ARRAY['needsMessage'::text, 'needsResponse'::text, 'convo'::text, 'messaged'::text, 'closed'::text, 'UPDATING'::text])", name: "campaign_contact_message_status_check"
  end

  create_table "canned_response", id: :serial, force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.text "text", null: false
    t.text "title", null: false
    t.integer "user_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["campaign_id"], name: "canned_response_campaign_id_index"
    t.index ["user_id"], name: "canned_response_user_id_index"
  end

  create_table "interaction_step", id: :serial, force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.text "question", default: "", null: false
    t.text "script", default: "", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "parent_interaction_id"
    t.text "answer_option", default: "", null: false
    t.text "answer_actions", default: "", null: false
    t.boolean "is_deleted", default: false, null: false
    t.text "answer_actions_data"
    t.index ["campaign_id"], name: "interaction_step_campaign_id_index"
    t.index ["parent_interaction_id"], name: "interaction_step_parent_interaction_id_index"
  end

  create_table "invite", id: :serial, force: :cascade do |t|
    t.boolean "is_valid", null: false
    t.text "hash"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["is_valid"], name: "invite_is_valid_index"
  end

  create_table "job_request", id: :serial, force: :cascade do |t|
    t.integer "campaign_id"
    t.text "payload", null: false
    t.text "queue_name", null: false
    t.text "job_type", null: false
    t.text "result_message", default: ""
    t.boolean "locks_queue", default: false
    t.boolean "assigned", default: false
    t.integer "status", default: 0
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "organization_id"
    t.index ["organization_id"], name: "job_request_organization_id_index"
    t.index ["queue_name"], name: "job_request_queue_name_index"
  end

  create_table "knex_migrations", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "batch"
    t.datetime "migration_time"
  end

  create_table "knex_migrations_lock", primary_key: "index", id: :serial, force: :cascade do |t|
    t.integer "is_locked"
  end

  create_table "log", id: :serial, force: :cascade do |t|
    t.text "message_sid", null: false
    t.text "body"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "error_code"
    t.string "from_num", limit: 15
    t.string "to_num", limit: 15
  end

  create_table "message", id: :serial, force: :cascade do |t|
    t.text "user_number", default: "", null: false
    t.integer "user_id"
    t.text "contact_number", null: false
    t.boolean "is_from_contact", null: false
    t.text "text", default: "", null: false
    t.integer "assignment_id"
    t.text "service", default: "", null: false
    t.text "service_id", default: "", null: false
    t.text "send_status", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "queued_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "sent_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "service_response_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "send_before"
    t.integer "error_code"
    t.integer "campaign_contact_id"
    t.text "messageservice_sid"
    t.jsonb "media"
    t.index ["campaign_contact_id"], name: "message_campaign_contact_id_index"
    t.index ["contact_number", "messageservice_sid", "user_number"], name: "cell_msgsvc_user_number_idx"
    t.index ["contact_number", "messageservice_sid"], name: "cell_messageservice_sid_idx"
    t.index ["send_status"], name: "message_send_status_index"
    t.index ["service_id"], name: "message_service_id_index"
    t.check_constraint "send_status = ANY (ARRAY['QUEUED'::text, 'SENDING'::text, 'SENT'::text, 'DELIVERED'::text, 'ERROR'::text, 'PAUSED'::text, 'NOT_ATTEMPTED'::text])", name: "message_send_status_check"
  end

  create_table "opt_out", id: :serial, force: :cascade do |t|
    t.text "cell", null: false
    t.integer "assignment_id"
    t.integer "organization_id", null: false
    t.text "reason_code", default: "", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["assignment_id"], name: "opt_out_assignment_id_index"
    t.index ["cell"], name: "opt_out_cell_index"
    t.index ["organization_id"], name: "opt_out_organization_id_index"
  end

  create_table "organization", id: :serial, force: :cascade do |t|
    t.text "uuid"
    t.text "name", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "features", default: ""
    t.boolean "texting_hours_enforced", default: false
    t.integer "texting_hours_start", default: 9
    t.integer "texting_hours_end", default: 21
  end

  create_table "organization_contact", id: :serial, force: :cascade do |t|
    t.integer "organization_id"
    t.text "contact_number", null: false
    t.text "user_number"
    t.text "service"
    t.integer "subscribe_status", default: 0
    t.integer "status_code"
    t.integer "last_error_code"
    t.text "carrier"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "last_lookup"
    t.text "lookup_name"
    t.index ["contact_number", "organization_id"], name: "organization_contact_contact_number_organization_id_unique", unique: true
    t.index ["contact_number", "organization_id"], name: "organization_contact_organization_contact_number"
    t.index ["organization_id", "user_number"], name: "organization_contact_organization_user_number"
    t.index ["status_code", "organization_id"], name: "organization_contact_status_code_organization_id"
  end

  create_table "owned_phone_number", id: :serial, force: :cascade do |t|
    t.string "service", limit: 255
    t.string "service_id", limit: 255
    t.integer "organization_id", null: false
    t.string "phone_number", limit: 255, null: false
    t.string "area_code", limit: 255, null: false
    t.string "allocated_to", limit: 255
    t.string "allocated_to_id", limit: 255
    t.datetime "allocated_at"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["allocated_to", "allocated_to_id"], name: "allocation_type_and_id_idx"
    t.index ["area_code"], name: "owned_phone_number_area_code_index"
    t.index ["organization_id"], name: "owned_phone_number_organization_id_index"
    t.index ["service", "service_id"], name: "owned_phone_number_service_service_id_unique", unique: true
  end

  create_table "pending_message_part", id: :serial, force: :cascade do |t|
    t.text "service", null: false
    t.text "service_id", null: false
    t.text "parent_id", default: ""
    t.text "service_message", null: false
    t.text "user_number", default: "", null: false
    t.text "contact_number", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["parent_id"], name: "pending_message_part_parent_id_index"
    t.index ["service"], name: "pending_message_part_service_index"
  end

  create_table "question_response", id: :serial, force: :cascade do |t|
    t.integer "campaign_contact_id", null: false
    t.integer "interaction_step_id", null: false
    t.text "value", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["campaign_contact_id"], name: "question_response_campaign_contact_id_index"
    t.index ["interaction_step_id"], name: "question_response_interaction_step_id_index"
  end

  create_table "tag", id: :serial, force: :cascade do |t|
    t.text "group"
    t.text "name", null: false
    t.text "description", null: false
    t.boolean "is_deleted", default: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "organization_id", null: false
    t.index ["organization_id", "is_deleted"], name: "tag_organization_id_is_deleted_index"
  end

  create_table "tag_campaign_contact", id: :serial, force: :cascade do |t|
    t.text "value"
    t.integer "tag_id", null: false
    t.integer "campaign_contact_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["campaign_contact_id"], name: "tag_campaign_contact_campaign_contact_id_index"
  end

  create_table "tag_canned_response", id: :serial, force: :cascade do |t|
    t.integer "canned_response_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["canned_response_id", "tag_id"], name: "tag_canned_response_canned_response_id_tag_id_unique", unique: true
    t.index ["canned_response_id"], name: "tag_canned_response_canned_response_id_index"
  end

  create_table "user", id: :serial, force: :cascade do |t|
    t.text "auth0_id", null: false
    t.text "first_name", null: false
    t.text "last_name", null: false
    t.text "cell", null: false
    t.text "email", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "assigned_cell"
    t.boolean "is_superadmin"
    t.boolean "terms", default: false
    t.string "alias", limit: 255
    t.jsonb "extra"
  end

  create_table "user_cell", id: :serial, force: :cascade do |t|
    t.text "cell", null: false
    t.integer "user_id", null: false
    t.text "service"
    t.boolean "is_primary"
    t.check_constraint "service = ANY (ARRAY['nexmo'::text, 'twilio'::text])", name: "user_cell_service_check"
  end

  create_table "user_organization", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "organization_id", null: false
    t.text "role", null: false
    t.index ["organization_id", "user_id"], name: "user_organization_organization_id_user_id_index"
    t.index ["organization_id"], name: "user_organization_organization_id_index"
    t.index ["user_id"], name: "user_organization_user_id_index"
    t.check_constraint "role = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'SUPERVOLUNTEER'::text, 'TEXTER'::text, 'VETTED_TEXTER'::text, 'ORG_SUPERADMIN'::text, 'SUSPENDED'::text])", name: "user_organization_role_check"
  end

  create_table "zip_code", primary_key: "zip", id: :text, force: :cascade do |t|
    t.text "city", null: false
    t.text "state", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.float "timezone_offset", null: false
    t.boolean "has_dst", null: false
  end

  add_foreign_key "assignment", "\"user\"", column: "user_id", name: "assignment_user_id_foreign"
  add_foreign_key "assignment", "campaign", name: "assignment_campaign_id_foreign"
  add_foreign_key "assignment_feedback", "\"user\"", column: "creator_id", name: "assignment_feedback_creator_id_foreign"
  add_foreign_key "assignment_feedback", "assignment", name: "assignment_feedback_assignment_id_foreign"
  add_foreign_key "campaign", "\"user\"", column: "creator_id", name: "campaign_creator_id_foreign"
  add_foreign_key "campaign", "organization", name: "campaign_organization_id_foreign"
  add_foreign_key "campaign_admin", "campaign", name: "campaign_admin_campaign_id_foreign"
  add_foreign_key "campaign_contact", "assignment", name: "campaign_contact_assignment_id_foreign"
  add_foreign_key "campaign_contact", "campaign", name: "campaign_contact_campaign_id_foreign"
  add_foreign_key "canned_response", "\"user\"", column: "user_id", name: "canned_response_user_id_foreign"
  add_foreign_key "canned_response", "campaign", name: "canned_response_campaign_id_foreign"
  add_foreign_key "interaction_step", "campaign", name: "interaction_step_campaign_id_foreign"
  add_foreign_key "interaction_step", "interaction_step", column: "parent_interaction_id", name: "interaction_step_parent_interaction_id_foreign"
  add_foreign_key "job_request", "campaign", name: "job_request_campaign_id_foreign"
  add_foreign_key "job_request", "organization", name: "job_request_organization_id_foreign"
  add_foreign_key "message", "\"user\"", column: "user_id", name: "message_user_id_foreign"
  add_foreign_key "message", "assignment", name: "message_assignment_id_foreign"
  add_foreign_key "message", "campaign_contact", name: "message_campaign_contact_id_foreign"
  add_foreign_key "opt_out", "assignment", name: "opt_out_assignment_id_foreign"
  add_foreign_key "opt_out", "organization", name: "opt_out_organization_id_foreign"
  add_foreign_key "organization_contact", "organization", name: "organization_contact_organization_id_foreign"
  add_foreign_key "owned_phone_number", "organization", name: "owned_phone_number_organization_id_foreign"
  add_foreign_key "question_response", "campaign_contact", name: "question_response_campaign_contact_id_foreign"
  add_foreign_key "question_response", "interaction_step", name: "question_response_interaction_step_id_foreign"
  add_foreign_key "tag", "organization", name: "tag_organization_id_foreign"
  add_foreign_key "tag_campaign_contact", "campaign_contact", name: "tag_campaign_contact_campaign_contact_id_foreign"
  add_foreign_key "tag_campaign_contact", "tag", name: "tag_campaign_contact_tag_id_foreign"
  add_foreign_key "tag_canned_response", "canned_response", name: "tag_canned_response_canned_response_id_foreign"
  add_foreign_key "tag_canned_response", "tag", name: "tag_canned_response_tag_id_foreign"
  add_foreign_key "user_cell", "\"user\"", column: "user_id", name: "user_cell_user_id_foreign"
  add_foreign_key "user_organization", "\"user\"", column: "user_id", name: "user_organization_user_id_foreign"
  add_foreign_key "user_organization", "organization", name: "user_organization_organization_id_foreign"

end
