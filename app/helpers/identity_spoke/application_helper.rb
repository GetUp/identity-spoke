module IdentitySpoke
  module ApplicationHelper
    def self.campaigns_for_select
      IdentitySpoke::Campaign.all.order("id DESC").map { |x| ["#{x.id}: #{x.title}", x.id] }
    end
  end
end
