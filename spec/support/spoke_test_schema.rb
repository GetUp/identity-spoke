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
    add_index 'campaign_contact', ['campaign_id', 'cell'], name: 'campaign_contact_cell_campaign_id_idx', unique: true, using: :btree
  end
end
