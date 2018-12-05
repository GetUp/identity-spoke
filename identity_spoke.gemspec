$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "identity_spoke/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "identity_spoke"
  s.version     = IdentitySpoke::VERSION
  s.authors     = ["GetUp!"]
  s.email       = ["tech@getup.org.au"]
  s.homepage    = "https://github.com/GetUp/identity_spoke"
  s.summary     = "Identity Spoke Integration."
  s.description = "Push members to Spoke Audience. Pull Responses to Contact Campaigns."
  s.license     = "TBD"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  s.add_dependency "rails"
  s.add_dependency "pg", "~> 0.18"
  s.add_dependency "active_model_serializers", "~> 0.10.7"

end
