# frozen_string_literal: true

class Sync < ApplicationRecord
  include Orderable
  include Searchable

  INITIALISING_STATUS = 'initialising'
  INITIALISED_STATUS = 'initialised'
  ACTIVE_STATUS = 'active'
  FINALISED_STATUS = 'finalised'
  FAILED_STATUS = 'failed'
  PUSH_SYNC_TYPE = 'push'
  PULL_SYNC_TYPE = 'pull'

  belongs_to :list
  belongs_to :contact_campaign, optional: true
  belongs_to :author, :class_name => 'Member'

  validates :sync_type, :status, presence: true
  validates :list, presence: true, :if => :is_push?

  scope :with_external_system, ->(external_system) {
    where(external_system: external_system) if external_system && external_system.present? && external_system != 'all'
  }

  scope :with_sync_type, ->(sync_type) {
    where(sync_type: sync_type) if sync_type && sync_type.present? && sync_type != 'all'
  }

  scope :pushes, -> { where({ :sync_type => PUSH_SYNC_TYPE }) }
  scope :pulls, -> { where({ :sync_type => PULL_SYNC_TYPE }) }

  def self.external_system_class(external_system)
    case external_system
    when 'facebook'
      ExternalSystems::IdentityFacebook
    when 'kooragang'
      require 'identity_kooragang' unless defined? IdentityKooragang
      'IdentityKooragang'.constantize
    when 'robotargeter'
      require 'identity_robotargeter' unless defined? IdentityRobotargeter
      'IdentityRobotargeter'.constantize
    when 'tijuana'
      require 'identity_tijuana' unless defined? IdentityTijuana
      'IdentityTijuana'.constantize
    when 'spoke'
      require 'identity_spoke' unless defined? IdentitySpoke
      'IdentitySpoke'.constantize
    when 'nation_builder'
      require 'identity_nation_builder' unless defined? IdentityNationBuilder
      'IdentityNationBuilder'.constantize
    when 'typeform'
      require 'identity_typeform' unless defined? IdentityTypeform
      'IdentityTypeform'.constantize
    when 'alchemer'
      ExternalSystems::IdentityAlchmer
    end
  end

  def self.initialise_pushes_from_list_creation(lists, services, current_account_id)
    lists.each do |list|
      services.each do |service|
        initialise_push_from_user(list.id, service['service'], service['options'], current_account_id)
      end
    end
  end

  def self.initialise_push_from_user(list_id, external_system, external_system_params, current_account_id)
    sync = where(
      external_system: external_system,
      external_system_params: external_system_params.to_json,
      sync_type: PUSH_SYNC_TYPE,
      list_id: list_id
    ).first_or_initialize
    if sync.new_record?
      sync.update!(author_id: current_account_id)
      PushListToServiceWorker.perform_async(sync.id)
    else
      raise StandardError, "List may already have been synced to external system: " + external_system
    end
  end

  def self.initialise_pull_from_system(external_system, pull_job, time_to_run)
    sync = Sync.create!(
      external_system: external_system,
      external_system_params: { pull_job: pull_job, time_to_run: time_to_run }.to_json,
      sync_type: PULL_SYNC_TYPE,
    )
    PullExternalSystemsWorker.perform_async(sync.id)
  end

  def self.pull_jobs_from_external_services
    ApplicationController.helpers.activated_external_services_for_pull.each do |external_service|
      external_system_class(external_service).get_pull_jobs.each do |pull_job|
        yield external_service, pull_job[0], pull_job[1] || 5.minutes
      end
    end
  end

  def is_pull?
    sync_type == PULL_SYNC_TYPE
  end

  def is_push?
    sync_type == PUSH_SYNC_TYPE
  end

  def initialised?
    status != INITIALISING_STATUS
  end

  def failed?
    status == FAILED_STATUS
  end

  def external_system_class
    Sync.external_system_class(external_system)
  end

  def job_type
    return JSON.parse(external_system_params)['pull_job'] if is_pull?

    JSON.parse(external_system_params)['sync_type'] || 'audience'
  end

  def get_external_system_settings
    case external_system
    when 'facebook'
      Settings.facebook
    when 'kooragang'
      Settings.kooragang
    when 'robotargeter'
      Settings.robotargeter
    when 'tijuana'
      Settings.tijuana
    when 'spoke'
      Settings.spoke
    when 'nation_builder'
      Settings.nation_builder
    when 'typeform'
      Settings.typeform
    when 'alchemer'
      Settings.alchemer
    end
  end

  def calc_progress(batch)
    (100 * batch * get_external_system_settings.push_batch_amount / list.member_count.to_f)
  end

  def set_status(status, finished = false, message = nil, progress = 0)
    update!(status: status, message: message, progress: progress)
    JobStatus.report(job_status_name, finished: finished, message: message, progress: progress)
  end

  def job_status_name
    if is_push?
      "Pushing list ##{list.id} '#{list.name}' to #{description}"
    else
      "Pulling data from #{description}"
    end
  end

  def description
    return "#{external_system_class::SYSTEM_NAME.titleize} Sync Loading..." if !initialised? && !failed?

    contact_campaign_name = contact_campaign ? contact_campaign.name : nil
    external_system_class.description(sync_type, external_system_params, contact_campaign_name)
  end

  def reset_imported_member_count
    update!(imported_member_count: 0)
  end

  def increment_imported_member_count(write_result_count)
    update!(imported_member_count: imported_member_count + write_result_count)
  end

  def initialialise_associated_contact_campaign(external_campaign_name)
    external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
    contact_campaign = ContactCampaign.where(
      name: external_campaign_name,
      contact_type: external_system_class::CONTACT_TYPE,
      system: external_system_class::SYSTEM_NAME,
      external_id: external_campaign_id
    ).first_or_initialize
    update!(contact_campaign: contact_campaign)
  end

  def push_to_external_service
    begin
      reset_imported_member_count
      service = external_system_class
      # load list member ids space-efficiently: 8 MiB per million members
      member_ids = ActiveRecord::Base.connection.raw_connection.async_exec(
        "SELECT member_id FROM list_members WHERE list_id = $1", [list.id]
      ).column_values(0)
      service.push(id, member_ids, external_system_params) do |members_for_service, external_campaign_name, latest_external_system_params|
        initialialise_associated_contact_campaign(external_campaign_name) if external_campaign_name
        set_status(INITIALISED_STATUS)
        service.push_in_batches(id, members_for_service, latest_external_system_params || external_system_params) do |batch_index, write_result_count|
          increment_imported_member_count(write_result_count)
          set_status(ACTIVE_STATUS, false, "Uploading batch ##{batch_index + 1}", calc_progress(batch_index + 1))
          GC.start
        end
        set_status(FINALISED_STATUS, true, nil, 100)
      end
    rescue => e
      set_status(FAILED_STATUS, true, "#{e.message}\n #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def pull_from_external_service
    begin
      reset_imported_member_count
      service = external_system_class
      set_status(INITIALISED_STATUS)

      set_finished = Proc.new do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        increment_imported_member_count(records_for_import_count)
        update!(
          records_for_import_scope: records_for_import_scope,
          pull_deferred: pull_deferred,
          records_for_import: records_for_import
        )
        message = pull_deferred ? 'Deferred as worker is currenly running' : nil
        set_status(FINALISED_STATUS, true, message, 100)
      end

      if service.respond_to?(:pull)
        service.pull(id, external_system_params, &set_finished)
      else # Some services don't need a special/custom pull method
        pull_job = JSON.parse(external_system_params)['pull_job'].to_s
        service.send(pull_job, id, &set_finished)
      end
    rescue => e
      set_status(FAILED_STATUS, true, "#{e.message}\n #{e.backtrace.join("\n")}")
      raise e
    end
  end
end
