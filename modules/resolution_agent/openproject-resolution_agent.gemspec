# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-resolution_agent"
  s.version     = "1.0.0"
  s.authors     = "OpenProject GmbH"
  s.email       = "info@openproject.com"
  s.summary     = "Work package resolution agent"
  s.description = "Conversational agent that checks a work package, records a summary, and hands it to R&D"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,frontend,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"

  s.add_dependency "openproject-llm", "~> 1.0"
end
