 class CreateSpokeTestDb < ActiveRecord::Migration[5.0]
  def up
    create_table 'organization', force: :cascade do |t|
      t.text     'uuid'
      t.text     'name', null: false
      t.datetime 'created_at', null: false, default: 'now()'
      t.text     'features'
      t.boolean  'texting_hours_enforced', default: false
      t.integer  'texting_hours_start', default: 9
      t.integer  'texting_hours_end', default: 21
    end
    create_table 'campaign', force: :cascade do |t|
      t.integer  'organization_id', null: false
      t.text     'title', null: false
      t.text     'description', null: false
      t.boolean  'is_started'
      t.datetime 'due_by'
      t.datetime 'created_at', null: false, default: 'now()'
      t.boolean  'is_archived'
      t.boolean  'use_dynamic_assignment', null: false, default: false
      t.text     'intro_html'
      t.text     'logo_image_url'
      t.text     'primary_color'
    end
    create_table 'campaign_contact', force: :cascade do |t|
      t.integer  'campaign_id', null: false
      t.integer  'assignment_id'
      t.integer  'external_id'
      t.text     'first_name', null: false
      t.text     'last_name', null: false
      t.text     'cell', null: false
      t.text     'zip'
      t.text     'custom_fields', null: false, default: '{}'
      t.datetime 'created_at', null: false, default: 'now()'
      t.text     'message_status', null: false, default: 'needsMessage'
      t.text     'time_offset'
    end
    create_table 'interaction_step', force: :cascade do |t|
      t.integer  'campaign_id', null: false
      t.text     'question', null: false
      t.text     'script', null: false
      t.datetime 'created_at', null: false, default: 'now()'
      t.integer  'parent_interaction_step_id'
      t.text     'answer_option', null: false
      t.text     'answer_actions', null: false
      t.boolean 'active', default: false
    end
    create_table 'question_response', force: :cascade do |t|
      t.integer  'campaign_contact_id', null: false
      t.integer  'interaction_step_id', null: false
      t.text     'value'
      t.datetime 'created_at', null: false, default: 'now()'
    end
    create_table 'assignment', force: :cascade do |t|
      t.integer  'user_id'
      t.integer  'campaign_id', null: false
      t.datetime 'created_at', null: false, default: 'now()'
      t.integer  'max_contacts'
      t.boolean 'active'
      t.float    'intensity'
    end
    create_table 'opt_out', force: :cascade do |t|
      t.text     'cell', null: false
      t.integer  'assignment_id'
      t.integer  'organization_id', null: false
      t.datetime 'created_at', null: false, default: 'now()'
    end
    create_table 'user', force: :cascade do |t|
      t.text     'auth0_id', null: false
      t.text     'first_name', null: false
      t.text     'last_name', null: false
      t.text     'cell', null: false
      t.text     'email', null: false
      t.text     'assigned_cell'
      t.boolean  'is_superadmin'
      t.boolean  'terms'
      t.datetime 'created_at', null: false, default: 'now()'
    end
    create_table 'message', force: :cascade do |t|
      t.text     'user_number', null: false
      t.text     'contact_number', null: false
      t.boolean  'is_from_contact', null: false
      t.text     'text', null: false
      t.text     'service_response', null: false
      t.integer  'assignment_id'
      t.text     'service'
      t.text     'service_id'
      t.text     'send_status'
      t.datetime 'created_at', null: false, default: 'now()'
      t.datetime 'queued_at', null: false, default: 'now()'
      t.datetime 'sent_at', null: false, default: 'now()'
      t.datetime 'service_response_at', null: false, default: 'now()'
    end
    add_index 'campaign_contact', ['campaign_id', 'cell'], name: 'campaign_contact_cell_campaign_id_idx', unique: true, using: :btree
  end
end
