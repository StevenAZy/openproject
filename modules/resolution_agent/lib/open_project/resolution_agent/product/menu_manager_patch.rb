# frozen_string_literal: true

module OpenProject
  module ResolutionAgent
    module Product
      module MenuManagerPatch
        TOP_MENU_ITEMS = %i[home projects work_packages].freeze
        PROJECT_MENU_ITEMS = %i[work_packages members settings].freeze
        WORK_PACKAGE_ITEMS = %i[overview activity files resolution_agent].freeze
        ADMIN_MENU_ITEMS = %i[
          admin_overview
          users_and_permissions
          users
          groups
          roles
          admin_work_packages
          types
          workflows
          statuses
          priorities
          work_package_custom_fields
          admin_projects_settings
          new_project_settings
          project_lists_settings
          ai
          llm_connection
          resolution_agent_settings
          backups
          info
        ].freeze

        def items(menu_name, project = nil)
          tree = super
          allowed = case menu_name.to_sym
                    when :top_menu then TOP_MENU_ITEMS
                    when :project_menu then PROJECT_MENU_ITEMS
                    when :work_package_split_view then WORK_PACKAGE_ITEMS
                    when :admin_menu then ADMIN_MENU_ITEMS
                    else return tree
                    end

          prune_product_menu(tree, allowed)
          tree
        end

        private

        def prune_product_menu(tree, allowed)
          tree.children.each do |node|
            if allowed.include?(node.name.to_sym)
              prune_product_menu(node, allowed)
            else
              tree.remove!(node)
            end
          end
        end
      end
    end
  end
end
