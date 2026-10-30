# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "open_project/plugins"

module OpenProject::ResolutionAgent
  class Engine < ::Rails::Engine
    engine_name :openproject_resolution_agent

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-resolution_agent",
             author_url: "https://www.openproject.org",
             bundled: true do
      menu :admin_menu,
           :resolution_agent_settings,
           { controller: "/resolution_agent/settings", action: :show },
           if: ->(*) { User.current.admin? },
           caption: :"resolution_agent.menu",
           parent: :ai

      menu :work_package_split_view,
           :resolution_agent,
           { tab: :resolution_agent },
           if: ->(*) { ::ResolutionAgent.enabled? },
           skip_permissions_check: true,
           caption: :"resolution_agent.title",
           after: :activity
    end

    initializer "resolution_agent.filter_token" do
      Rails.application.config.filter_parameters << :gitea_token
      Rails.application.config.filter_parameters << :llm_api_key
    end
  end
end

module ResolutionAgent
  def self.enabled?
    Setting.enabled?
  end
end
