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

import { Controller } from '@hotwired/stimulus';
import { renderStreamMessage } from '@hotwired/turbo';

const STREAM_TYPE = 'text/vnd.turbo-stream.html';
const POLLING_INTERVAL = 2000;
const ELAPSED_INTERVAL = 1000;

export default class PollingController extends Controller<HTMLElement> {
  static targets = ['poll', 'finished', 'transcript', 'elapsed', 'submit', 'typing'];

  declare readonly transcriptTarget:HTMLElement;
  declare readonly elapsedTarget:HTMLElement;
  declare readonly submitTarget:HTMLButtonElement;
  declare readonly hasTranscriptTarget:boolean;
  declare readonly hasElapsedTarget:boolean;
  declare readonly hasSubmitTarget:boolean;

  pollingInterval?:ReturnType<typeof setInterval>;
  elapsedInterval?:ReturnType<typeof setInterval>;
  typingInterval?:ReturnType<typeof setInterval>;

  connect() {
    requestAnimationFrame(() => this.restoreScroll());
  }

  pollTargetConnected(element:HTMLElement) {
    const url = element.dataset.url;
    if (!url) { return; }

    this.pollingInterval ??= setInterval(() => { void this.refresh(url); }, POLLING_INTERVAL);
  }

  pollTargetDisconnected() {
    this.stopPolling();
  }

  elapsedTargetConnected() {
    this.updateElapsed();
    this.elapsedInterval ??= setInterval(() => this.updateElapsed(), ELAPSED_INTERVAL);
  }

  elapsedTargetDisconnected() {
    this.stopElapsed();
  }

  finishedTargetConnected() {
    this.stopPolling();
    this.stopElapsed();
    requestAnimationFrame(() => this.scrollToLatest());
  }

  typingTargetConnected(element:HTMLElement) {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) { return; }

    const finalHtml = element.innerHTML;
    const text = element.textContent ?? '';
    const chunkSize = Math.max(1, Math.ceil(text.length / 200));
    let offset = 0;

    element.textContent = '';
    element.setAttribute('aria-live', 'polite');
    this.typingInterval = setInterval(() => {
      const shouldScroll = this.isNearLatest();
      offset = Math.min(text.length, offset + chunkSize);
      element.textContent = text.slice(0, offset);
      if (shouldScroll) { this.scrollToLatest(true); }
      if (offset === text.length) {
        this.stopTyping();
        element.innerHTML = finalHtml;
      }
    }, 20);
  }

  submitting() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true;
    }
  }

  composerKeydown(event:KeyboardEvent) {
    if (event.key !== 'Enter' || event.shiftKey || event.isComposing) { return; }

    event.preventDefault();
    (event.currentTarget as HTMLTextAreaElement).form?.requestSubmit();
  }

  disconnect() {
    this.storeScroll();
    this.stopPolling();
    this.stopElapsed();
    this.stopTyping();
  }

  private async refresh(url:string) {
    let stream:string|null;

    try {
      stream = await this.streamFrom(url);
    } catch {
      return;
    }

    if (stream === null) {
      this.stopPolling();
      return;
    }

    renderStreamMessage(stream);
  }

  private async streamFrom(url:string):Promise<string|null> {
    const response = await fetch(url, { headers: { Accept: STREAM_TYPE } });

    if (!response.ok || !(response.headers.get('Content-Type') ?? '').includes(STREAM_TYPE)) {
      return null;
    }

    return response.text();
  }

  private updateElapsed() {
    if (!this.hasElapsedTarget) { return; }

    const startedAt = Number(this.elapsedTarget.dataset.startedAt);
    const template = this.elapsedTarget.dataset.template;
    if (!startedAt || !template) { return; }

    const seconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
    this.elapsedTarget.textContent = template.replace('__SECONDS__', seconds.toString());
  }

  private scrollToLatest(force = false) {
    if (this.hasTranscriptTarget && (force || this.isNearLatest())) {
      this.transcriptTarget.scrollTop = this.transcriptTarget.scrollHeight;
    }
  }

  private isNearLatest():boolean {
    if (!this.hasTranscriptTarget) { return false; }

    const transcript = this.transcriptTarget;
    return transcript.scrollHeight - transcript.scrollTop - transcript.clientHeight < 80;
  }

  private storeScroll() {
    const key = this.element.dataset.scrollKey;
    if (!key || !this.hasTranscriptTarget) { return; }

    if (this.isNearLatest()) {
      sessionStorage.removeItem(key);
    } else {
      sessionStorage.setItem(key, this.transcriptTarget.scrollTop.toString());
    }
  }

  private restoreScroll() {
    const key = this.element.dataset.scrollKey;
    const stored = key && sessionStorage.getItem(key);
    if (stored && this.hasTranscriptTarget) {
      this.transcriptTarget.scrollTop = Number(stored);
    } else {
      this.scrollToLatest(true);
    }
  }

  private stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
      this.pollingInterval = undefined;
    }
  }

  private stopElapsed() {
    if (this.elapsedInterval) {
      clearInterval(this.elapsedInterval);
      this.elapsedInterval = undefined;
    }
  }

  private stopTyping() {
    if (this.typingInterval) {
      clearInterval(this.typingInterval);
      this.typingInterval = undefined;
    }
  }
}
