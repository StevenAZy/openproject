# frozen_string_literal: true

module ResolutionAgent
  class SettingsForm < ApplicationForm
    form do |f|
      f.fieldset_group(title: I18n.t("resolution_agent.settings.enabled")) do |group|
        group.check_box(
          name: :enabled,
          label: I18n.t("resolution_agent.settings.enabled")
        )
      end

      f.fieldset_group(title: I18n.t("resolution_agent.settings.accounts")) do |group|
        group.select_list(
          name: :service_account_id,
          label: I18n.t("resolution_agent.settings.service_account"),
          include_blank: true,
          input_width: :large
        ) do |list|
          assignable_users.each do |user|
            list.option(label: user.name, value: user.id, selected: model.service_account_id == user.id)
          end
        end

        group.select_list(
          name: :rd_supervisor_id,
          label: I18n.t("resolution_agent.settings.supervisor"),
          include_blank: true,
          input_width: :large
        ) do |list|
          assignable_users.each do |user|
            list.option(label: user.name, value: user.id, selected: model.rd_supervisor_id == user.id)
          end
        end
      end

      f.fieldset_group(
        title: I18n.t("resolution_agent.settings.llm"),
        description: I18n.t("resolution_agent.settings.llm_hint")
      ) do |group|
        group.text_field(
          name: :llm_base_url,
          label: I18n.t("resolution_agent.settings.llm_base_url"),
          type: :url,
          placeholder: "http://127.0.0.1:8000/v1",
          input_width: :large
        )
        group.text_field(
          name: :llm_model,
          label: I18n.t("resolution_agent.settings.llm_model"),
          input_width: :large
        )
        group.text_field(
          name: :llm_api_key,
          label: I18n.t("resolution_agent.settings.llm_api_key"),
          type: :password,
          value: nil,
          autocomplete: "new-password",
          input_width: :large
        )
      end

      f.fieldset_group(title: I18n.t("resolution_agent.settings.gitea")) do |group|
        group.text_field(
          name: :gitea_base_url,
          label: I18n.t("resolution_agent.settings.gitea_base_url"),
          type: :url,
          input_width: :large
        )
        group.text_field(
          name: :gitea_token,
          label: I18n.t("resolution_agent.settings.gitea_token"),
          type: :password,
          value: nil,
          autocomplete: "new-password",
          input_width: :large
        )
      end

      f.submit(name: :submit, label: I18n.t(:button_save), scheme: :primary)
    end

    private

    def assignable_users
      @assignable_users ||= User.not_locked.where(type: "User").order(:lastname, :firstname)
    end
  end
end
