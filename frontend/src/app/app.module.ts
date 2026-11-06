//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { ApplicationRef, DoBootstrap, inject, Injector, NgModule, provideAppInitializer } from '@angular/core';
import { A11yModule } from '@angular/cdk/a11y';
import { HTTP_INTERCEPTORS, HttpClient, provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';
import { ReactiveFormsModule } from '@angular/forms';
import {
  OpContextMenuTrigger,
} from 'core-app/shared/components/op-context-menu/handlers/op-context-menu-trigger.directive';
import { States } from 'core-app/core/states/states.service';
import { OpenprojectFieldsModule } from 'core-app/shared/components/fields/openproject-fields.module';
import { OpSharedModule } from 'core-app/shared/shared.module';
import { OpSpotModule } from 'core-app/spot/spot.module';
import { OpDragScrollDirective } from 'core-app/shared/directives/op-drag-scroll/op-drag-scroll.directive';
import { OpenprojectWorkPackagesModule } from 'core-app/features/work-packages/openproject-work-packages.module';
import { OpenprojectAttachmentsModule } from 'core-app/shared/components/attachments/openproject-attachments.module';
import { OpenprojectEditorModule } from 'core-app/shared/components/editor/openproject-editor.module';
import { BrowserModule } from '@angular/platform-browser';
import { OpenprojectGlobalSearchModule } from 'core-app/core/global_search/openproject-global-search.module';
import { KeyboardShortcutService } from 'core-app/shared/directives/a11y/keyboard-shortcut.service';
import { CopyToClipboardService } from 'core-app/shared/components/copy-to-clipboard/copy-to-clipboard.service';
import {
  OpenprojectMembersModule,
} from 'core-app/shared/components/autocompleter/members-autocompleter/members.module';
import { OpenprojectAugmentingModule } from 'core-app/core/augmenting/openproject-augmenting.module';
import { OpenprojectModalModule } from 'core-app/shared/components/modal/modal.module';
import { ConfirmDialogService } from 'core-app/shared/components/modals/confirm-dialog/confirm-dialog.service';
import { ConfirmDialogModalComponent } from 'core-app/shared/components/modals/confirm-dialog/confirm-dialog.modal';
import { DynamicContentModalComponent } from 'core-app/shared/components/modals/modal-wrapper/dynamic-content.modal';
import { PaginationService } from 'core-app/shared/components/table-pagination/pagination-service';
import { MainMenuResizerComponent } from 'core-app/shared/components/resizer/resizer/main-menu-resizer.component';
import { OpenprojectTabsModule } from 'core-app/shared/components/tabs/openproject-tabs.module';
import { OpenprojectAdminModule } from 'core-app/features/admin/openproject-admin.module';
import { OpenprojectHalModule } from 'core-app/features/hal/openproject-hal.module';
import { OpenprojectPluginsModule } from 'core-app/features/plugins/openproject-plugins.module';
import { LinkedPluginsModule } from 'core-app/features/plugins/linked-plugins.module';
import {
  OpenProjectInAppNotificationsModule,
} from 'core-app/features/in-app-notifications/in-app-notifications.module';
import { OpenProjectStateModule } from 'core-app/core/state/openproject-state.module';
import {
  OpenprojectContentLoaderModule,
} from 'core-app/shared/components/op-content-loader/openproject-content-loader.module';
import { OpenProjectHeaderInterceptor } from 'core-app/features/hal/http/openproject-header-interceptor';
import { TopMenuService } from 'core-app/core/top-menu/top-menu.service';
import { OpUploadService } from 'core-app/core/upload/upload.service';
import { ConfigurationService } from 'core-app/core/config/configuration.service';
import { FogUploadService } from 'core-app/core/upload/fog-upload.service';
import { LocalUploadService } from 'core-app/core/upload/local-upload.service';
import { registerCustomElement } from 'core-app/shared/helpers/angular/custom-elements.helper';
import {
  EmbeddedTablesMacroComponent,
} from 'core-app/features/work-packages/components/wp-table/embedded/embedded-tables-macro.component';
import {
  WorkPackageEmbeddedTableEntryComponent,
} from 'core-app/features/work-packages/components/wp-table/embedded/wp-embedded-table-entry.component';
import { OpPrincipalComponent } from 'core-app/shared/components/principal/principal.component';
import {
  OpBasicSingleDatePickerComponent,
} from 'core-app/shared/components/datepicker/basic-single-date-picker/basic-single-date-picker.component';
import {
  OpBasicSingleDatetimePickerComponent,
} from 'core-app/shared/components/datepicker/basic-single-datetime-picker/basic-single-datetime-picker.component';
import {
  OpBasicRangeDatePickerComponent,
} from 'core-app/shared/components/datepicker/basic-range-date-picker/basic-range-date-picker.component';
import { GlobalSearchInputComponent } from 'core-app/core/global_search/input/global-search-input.component';
import {
  OpAutocompleterComponent,
} from 'core-app/shared/components/autocompleter/op-autocompleter/op-autocompleter.component';
import {
  ProjectAutocompleterComponent,
} from 'core-app/shared/components/autocompleter/project-autocompleter/project-autocompleter.component';
import {
  MembersAutocompleterComponent,
} from 'core-app/shared/components/autocompleter/members-autocompleter/members-autocompleter.component';
import {
  UserAutocompleterComponent,
} from 'core-app/shared/components/autocompleter/user-autocompleter/user-autocompleter.component';
import { AttributeValueMacroComponent } from 'core-app/shared/components/fields/macros/attribute-value-macro.component';
import { AttributeLabelMacroComponent } from 'core-app/shared/components/fields/macros/attribute-label-macro.component';
import {
  WorkPackageQuickinfoMacroComponent,
} from 'core-app/shared/components/fields/macros/work-package-quickinfo-macro.component';
import {
  CkeditorAugmentedTextareaComponent,
} from 'core-app/shared/components/editor/components/ckeditor-augmented-textarea/ckeditor-augmented-textarea.component';
import {
  DraggableAutocompleteComponent,
} from 'core-app/shared/components/autocompleter/draggable-autocomplete/draggable-autocomplete.component';
import { OpenProjectJobStatusModule } from 'core-app/features/job-status/openproject-job-status.module';
import { OpenProjectMyAccountModule } from 'core-app/features/user-preferences/user-preferences.module';
import { OpAttachmentsComponent } from 'core-app/shared/components/attachments/attachments.component';
import {
  InAppNotificationCenterComponent,
} from 'core-app/features/in-app-notifications/center/in-app-notification-center.component';
import {
  WorkPackageSplitViewEntryComponent,
} from 'core-app/features/work-packages/routing/wp-split-view/wp-split-view-entry.component';
import {
  WorkPackageSplitCreateEntryComponent,
} from 'core-app/features/work-packages/routing/wp-split-create/wp-split-create-entry.component';
import { OpCustomModalOverlayComponent } from 'core-app/shared/components/modal/custom-modal-overlay.component';
import {
  RemoteFieldUpdaterComponent,
} from 'core-app/shared/components/remote-field-updater/remote-field-updater.component';
import { SpotDropModalPortalComponent } from 'core-app/spot/components/drop-modal/drop-modal-portal.component';
import { OpModalOverlayComponent } from 'core-app/shared/components/modal/modal-overlay.component';
import {
  InAppNotificationBellComponent,
} from 'core-app/features/in-app-notifications/bell/in-app-notification-bell.component';
import {
  EditableQueryPropsComponent,
} from 'core-app/features/admin/editable-query-props/editable-query-props.component';
import { NoResultsComponent } from 'core-app/shared/components/no-results/no-results.component';
import {
  OpNonWorkingDaysListComponent,
} from 'core-app/shared/components/op-non-working-days-list/op-non-working-days-list.component';
import { PersistentToggleComponent } from 'core-app/shared/components/persistent-toggle/persistent-toggle.component';
import { ToastsContainerComponent } from 'core-app/shared/components/toaster/toasts-container.component';
import { GlobalSearchWorkPackagesComponent } from 'core-app/core/global_search/global-search-work-packages.component';
import {
  ZenModeButtonComponent,
} from 'core-app/features/work-packages/components/wp-buttons/zen-mode-toggle-button/zen-mode-toggle-button.component';
import { ColorsAutocompleterComponent } from 'core-app/shared/components/colors/colors-autocompleter.component';
import {
  StaticAttributeHelpTextComponent,
} from 'core-app/shared/components/attribute-help-texts/static-attribute-help-text.component';
import { SpotSwitchComponent } from 'core-app/spot/components/switch/switch.component';
import { OPContextMenuService } from 'core-app/shared/components/op-context-menu/op-context-menu.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import {
  OpWpDatePickerInstanceComponent,
} from 'core-app/shared/components/datepicker/wp-date-picker-modal/wp-date-picker-instance.component';
import { AppBadgeService } from 'core-app/features/in-app-notifications/bell/app-badge.service';
import { WorkPackageFullCopyEntryComponent } from 'core-app/features/work-packages/routing/wp-full-copy/wp-full-copy-entry.component';
import { WorkPackageFullCreateEntryComponent } from 'core-app/features/work-packages/routing/wp-full-create/wp-full-create-entry.component';
import { WorkPackageFullViewEntryComponent } from 'core-app/features/work-packages/routing/wp-full-view/wp-full-view-entry.component';
import { WorkPackageViewPageEntryComponent } from 'core-app/features/work-packages/routing/wp-view-page/wp-view-page-entry.component';

export function initializeServices(injector:Injector) {
  return () => {
    const topMenuService = injector.get(TopMenuService);
    const keyboardShortcuts = injector.get(KeyboardShortcutService);
    const contextMenu = injector.get(OPContextMenuService);
    const currentProject = injector.get(CurrentProjectService);

    const runOnRenderAndLoad = () => {
      topMenuService.register();
      contextMenu.register();
      currentProject.detect();
    };
    runOnRenderAndLoad();

    // Register on turbo:render, turbo:load
    document.addEventListener('turbo:render', runOnRenderAndLoad);
    document.addEventListener('turbo:load', runOnRenderAndLoad);

    keyboardShortcuts.register();

    const configuration = injector.get(ConfigurationService).initialize();
    void configuration.then(() => injector.get(AppBadgeService).initialize()).catch(() => undefined);
    return configuration;
  };
}

@NgModule({
  declarations: [
    OpContextMenuTrigger,

    // Modals
    ConfirmDialogModalComponent,
    DynamicContentModalComponent,

    // Main menu
    MainMenuResizerComponent,

    // Form configuration
    OpDragScrollDirective,
  ],
  imports: [
    // The BrowserModule must only be loaded here!
    BrowserModule,
    A11yModule,

    // Commons
    OpSharedModule,
    // Design System
    OpSpotModule,
    // State module
    OpenProjectStateModule,
    // Hal Module
    OpenprojectHalModule,
    OpenProjectJobStatusModule,

    // CKEditor
    OpenprojectEditorModule,
    // Display + Edit field functionality
    OpenprojectFieldsModule,
    OpenprojectAttachmentsModule,

    // Work packages
    OpenprojectWorkPackagesModule,

    // Global Search
    OpenprojectGlobalSearchModule,

    // Admin module
    OpenprojectAdminModule,
    // Plugin hooks and modules
    OpenprojectPluginsModule,
    // Linked plugins dynamically generated by bundler
    LinkedPluginsModule,

    // Members
    OpenprojectMembersModule,

    // Angular Forms
    ReactiveFormsModule,

    // Augmenting Module
    OpenprojectAugmentingModule,

    // Modals
    OpenprojectModalModule,

    // Tabs
    OpenprojectTabsModule,

    // Notifications
    OpenProjectInAppNotificationsModule,

    // Loading
    OpenprojectContentLoaderModule,

    // My account
    OpenProjectMyAccountModule,
  ],
  providers: [
    { provide: States, useValue: new States() },
    { provide: HTTP_INTERCEPTORS, useClass: OpenProjectHeaderInterceptor, multi: true },
    provideAppInitializer(() => {
      const initializerFn = (initializeServices)(inject(Injector));
      return initializerFn();
    }),
    {
      provide: OpUploadService,
      useFactory: (config:ConfigurationService, http:HttpClient) => (config.isDirectUploads() ? new FogUploadService(http) : new LocalUploadService(http)),
      deps: [ConfigurationService, HttpClient],
    },
    PaginationService,
    ConfirmDialogService,
    CopyToClipboardService,
    provideHttpClient(withXhr(), withInterceptorsFromDi()),
  ],
})
export class OpenProjectModule implements DoBootstrap {
  // noinspection JSUnusedGlobalSymbols
  ngDoBootstrap(appRef:ApplicationRef) {
    document.body.classList.add('__ng2-bootstrap-has-run');
    this.registerCustomElements(appRef.injector);
  }

  private registerCustomElements(injector:Injector) {
    registerCustomElement('opce-macro-embedded-table', EmbeddedTablesMacroComponent, { injector });
    registerCustomElement('opce-embedded-work-package-table', WorkPackageEmbeddedTableEntryComponent, { injector });
    registerCustomElement('opce-principal', OpPrincipalComponent, { injector });
    registerCustomElement('opce-basic-single-date-picker', OpBasicSingleDatePickerComponent, { injector });
    registerCustomElement('opce-basic-single-datetime-picker', OpBasicSingleDatetimePickerComponent, { injector });
    registerCustomElement('opce-range-date-picker', OpBasicRangeDatePickerComponent, { injector });
    registerCustomElement('opce-global-search', GlobalSearchInputComponent, { injector });
    registerCustomElement('opce-autocompleter', OpAutocompleterComponent, { injector });
    registerCustomElement('opce-project-autocompleter', ProjectAutocompleterComponent, { injector });
    registerCustomElement('opce-members-autocompleter', MembersAutocompleterComponent, { injector });
    registerCustomElement('opce-user-autocompleter', UserAutocompleterComponent, { injector });
    registerCustomElement('opce-macro-attribute-value', AttributeValueMacroComponent, { injector });
    registerCustomElement('opce-macro-attribute-label', AttributeLabelMacroComponent, { injector });
    registerCustomElement('opce-macro-wp-quickinfo', WorkPackageQuickinfoMacroComponent, { injector });
    registerCustomElement('opce-ckeditor-augmented-textarea', CkeditorAugmentedTextareaComponent, { injector });
    registerCustomElement('opce-draggable-autocompleter', DraggableAutocompleteComponent, { injector });
    registerCustomElement('opce-static-attribute-help-text', StaticAttributeHelpTextComponent, { injector });
    registerCustomElement('opce-attachments', OpAttachmentsComponent, { injector });
    registerCustomElement('opce-custom-modal-overlay', OpCustomModalOverlayComponent, { injector });

    registerCustomElement('opce-notification-center', InAppNotificationCenterComponent, { injector });
    registerCustomElement('opce-wp-split-view', WorkPackageSplitViewEntryComponent, { injector });
    registerCustomElement('opce-wp-split-create', WorkPackageSplitCreateEntryComponent, { injector });
    registerCustomElement('opce-wp-full-view', WorkPackageFullViewEntryComponent, { injector });
    registerCustomElement('opce-work-packages-view', WorkPackageViewPageEntryComponent, { injector });
    registerCustomElement('opce-wp-full-create', WorkPackageFullCreateEntryComponent, { injector });
    registerCustomElement('opce-wp-full-copy', WorkPackageFullCopyEntryComponent, { injector });
    registerCustomElement('opce-remote-field-updater', RemoteFieldUpdaterComponent, { injector });
    registerCustomElement('opce-wp-date-picker-instance', OpWpDatePickerInstanceComponent, { injector });
    registerCustomElement('opce-spot-drop-modal-portal', SpotDropModalPortalComponent, { injector });
    registerCustomElement('opce-spot-switch', SpotSwitchComponent, { injector });
    registerCustomElement('opce-modal-overlay', OpModalOverlayComponent, { injector });
    registerCustomElement('opce-in-app-notification-bell', InAppNotificationBellComponent, { injector });
    registerCustomElement('opce-editable-query-props', EditableQueryPropsComponent, { injector });
    registerCustomElement('opce-no-results', NoResultsComponent, { injector });
    registerCustomElement('opce-non-working-days-list', OpNonWorkingDaysListComponent, { injector });
    registerCustomElement('opce-main-menu-resizer', MainMenuResizerComponent, { injector });
    registerCustomElement('opce-persistent-toggle', PersistentToggleComponent, { injector });
    registerCustomElement('opce-toasts-container', ToastsContainerComponent, { injector });
    registerCustomElement('opce-global-search-work-packages', GlobalSearchWorkPackagesComponent, { injector });
    registerCustomElement('opce-zen-mode-toggle-button', ZenModeButtonComponent, { injector });
    registerCustomElement('opce-colors-autocompleter', ColorsAutocompleterComponent, { injector });
  }
}
