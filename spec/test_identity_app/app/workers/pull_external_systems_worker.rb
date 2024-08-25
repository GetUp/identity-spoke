class PullExternalSystemsWorker
  include Sidekiq::Worker
  sidekiq_options lock: :until_and_while_executing, ttl: 60 * 60, on_conflict: { client: :log, server: :reject }
  sidekiq_options retry: false

  def perform(sync_id)
    sync = Sync.find(sync_id)
    Rails.logger.info "PullExternalSystemsWorker called with sync_id=#{sync_id}"
    sync.pull_from_external_service
    ActiveRecord::Base.clear_active_connections!
  end
end
