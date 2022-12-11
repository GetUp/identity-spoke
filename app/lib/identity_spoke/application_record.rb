module IdentitySpoke
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.set_db_pool_size(db_url_string)
      if db_url_string
        db_url = URI.parse db_url_string
        pool_size = ENV['RAILS_MAX_THREADS'] || 5
        qs_hash = db_url.query ? CGI.parse(db_url.query) : { }
        qs_hash['pool'] = pool_size if !qs_hash['pool']
        db_url.query = URI.encode_www_form(qs_hash)
        db_url.to_s
      end
    end
  end
end
