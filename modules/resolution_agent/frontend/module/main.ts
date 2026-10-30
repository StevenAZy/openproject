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

import { CUSTOM_ELEMENTS_SCHEMA, Injector, NgModule, inject } from '@angular/core';

import { OpSharedModule } from 'core-app/shared/shared.module';
import { OpenprojectTabsModule } from 'core-app/shared/components/tabs/openproject-tabs.module';
import {
  WorkPackageTabsService,
} from 'core-app/features/work-packages/components/wp-tabs/services/wp-tabs/wp-tabs.service';

import { ResolutionAgentTabComponent } from './resolution-agent-tab/resolution-agent-tab.component';

export function initializeResolutionAgentPlugin(injector:Injector) {
  const wpTabService = injector.get(WorkPackageTabsService);
  wpTabService.registerBefore(
    'watchers',
    {
      component: ResolutionAgentTabComponent,
      name: I18n.t('js.work_packages.tabs.resolution_agent'),
      id: 'resolution_agent',
    },
  );
}

@NgModule({
  imports: [
    OpSharedModule,
    OpenprojectTabsModule,
  ],
  declarations: [
    ResolutionAgentTabComponent,
  ],
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
})
export class PluginModule {
  constructor() {
    const injector = inject(Injector);

    initializeResolutionAgentPlugin(injector);
  }
}
