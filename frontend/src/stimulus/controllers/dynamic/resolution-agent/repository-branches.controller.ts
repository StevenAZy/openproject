//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.

import { Controller } from '@hotwired/stimulus';

export default class RepositoryBranchesController extends Controller {
  static values = { url: String };
  static targets = ['repository', 'branch'];

  declare readonly urlValue:string;
  declare readonly repositoryTarget:HTMLSelectElement;
  declare readonly branchTarget:HTMLSelectElement;

  async load() {
    this.branchTarget.replaceChildren(new Option('', ''));
    if (!this.repositoryTarget.value) {
      return;
    }

    this.branchTarget.disabled = true;
    try {
      const url = new URL(this.urlValue, window.location.origin);
      url.searchParams.set('repository_id', this.repositoryTarget.value);
      const response = await fetch(url, { headers: { Accept: 'application/json' } });
      const payload = await response.json() as string[]|{ error:string };
      if (!response.ok || !Array.isArray(payload)) {
        throw new Error(Array.isArray(payload) ? '' : payload.error);
      }

      payload.forEach((branch) => this.branchTarget.add(new Option(branch, branch)));
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      this.branchTarget.add(new Option(message || 'Unable to load branches', ''));
    } finally {
      this.branchTarget.disabled = false;
    }
  }
}
