Rails.application.routes.draw do
  mount IdentitySpoke::Engine => "/identity_spoke"
end
