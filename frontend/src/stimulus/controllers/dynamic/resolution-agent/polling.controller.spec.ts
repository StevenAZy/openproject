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

import { vi, type Mock } from 'vitest';

import { setupStimulusTest, type StimulusTestContext } from 'core-stimulus/test-helpers';
import type PollingControllerType from './polling.controller';

const IDENTIFIER = 'resolution-agent--polling';
const STATUS_URL = '/projects/demo/work_packages/2/resolution_agent/status?job=abc';

describe('Resolution agent polling controller', () => {
  let ctx:StimulusTestContext;
  let PollingController:typeof PollingControllerType;
  let fetchSpy:Mock;

  beforeAll(async () => {
    ({ default: PollingController } = await import('./polling.controller'));
  });

  beforeEach(async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
    fetchSpy = vi.fn();
    vi.spyOn(window, 'fetch').mockImplementation(fetchSpy);
    ctx = await setupStimulusTest({ controllers: { [IDENTIFIER]: PollingController } });
  });

  afterEach(async () => {
    ctx.dispose();
    await ctx.nextFrame();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  function pollMarker() {
    return `<span hidden data-${IDENTIFIER}-target="poll" data-url="${STATUS_URL}"></span>`;
  }

  function stream(inner:string) {
    return new Response(
      `<turbo-stream action="replace" target="agent">
         <template><div id="agent">${inner}</div></template>
       </turbo-stream>`,
      { status: 200, headers: { 'Content-Type': 'text/vnd.turbo-stream.html' } },
    );
  }

  async function mount(inner = pollMarker()) {
    await ctx.mount(`
      <div data-controller="${IDENTIFIER}">
        <div id="agent">${inner}</div>
      </div>
    `);
  }

  it('polls every two seconds and renders the returned stream', async () => {
    fetchSpy.mockResolvedValue(stream('<p id="answer">Done</p>'));
    await mount();

    await vi.advanceTimersByTimeAsync(2000);
    await ctx.nextFrame();
    await ctx.nextFrame();

    expect(fetchSpy).toHaveBeenCalledWith(STATUS_URL, {
      headers: { Accept: 'text/vnd.turbo-stream.html' },
    });
    expect(ctx.container.querySelector('#answer')).not.toBeNull();
  });

  it('keeps polling after a temporary network failure', async () => {
    fetchSpy.mockRejectedValueOnce(new TypeError('offline')).mockResolvedValue(stream(pollMarker()));
    await mount();

    await vi.advanceTimersByTimeAsync(4000);

    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it('stops polling when a finished marker is rendered', async () => {
    fetchSpy.mockResolvedValue(stream(`<span hidden data-${IDENTIFIER}-target="finished"></span>`));
    await mount();

    await vi.advanceTimersByTimeAsync(2000);
    await ctx.nextFrame();
    await ctx.nextFrame();
    await vi.advanceTimersByTimeAsync(2000);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('disables the submit button immediately', async () => {
    await ctx.mount(`
      <form data-controller="${IDENTIFIER}" data-action="submit->${IDENTIFIER}#submitting">
        <button data-${IDENTIFIER}-target="submit">Send</button>
      </form>
    `);

    const form = ctx.container.querySelector('form')!;
    const button = ctx.container.querySelector('button')!;
    form.addEventListener('submit', (event) => event.preventDefault());
    form.dispatchEvent(new SubmitEvent('submit', { bubbles: true, cancelable: true }));

    expect(button).toBeDisabled();
  });

  it('reveals a completed answer with a typing effect', async () => {
    await ctx.mount(`
      <div data-controller="${IDENTIFIER}">
        <div data-${IDENTIFIER}-target="transcript">
          <div data-${IDENTIFIER}-target="typing">A concise agent answer.</div>
        </div>
      </div>
    `);

    const answer = ctx.container.querySelector<HTMLElement>(`[data-${IDENTIFIER}-target="typing"]`)!;
    expect(answer.textContent).toBe('');

    await vi.advanceTimersByTimeAsync(4000);

    expect(answer.textContent).toBe('A concise agent answer.');
  });
});
