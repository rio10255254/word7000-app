import Anthropic from '@anthropic-ai/sdk';
import { type Effort, MODEL, type TaskPlan } from './tasks.ts';

export type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export interface Completion {
  model: string;
  effort: Effort;
  content: unknown;
}

/** Why Claude did not answer. `busy` and `unavailable` let the app fall back to the on-device model. */
export class AIFailure extends Error {
  constructor(readonly kind: 'busy' | 'unavailable' | 'misconfigured', message: string, readonly retryAfter?: number) {
    super(message);
  }
}

export interface CompleteOptions {
  apiKey: string;
  fetch?: Fetch;
  /** Per attempt, so a stalled attempt still leaves time for a quicker retry. */
  attemptTimeoutMs?: number;
  /** Below the app's own 30 second wait. */
  totalTimeoutMs?: number;
  now?: () => number;
}

/**
 * Thinking counts toward max_tokens, so each level gets room to think on top
 * of the answer; without it a long think could stop before any answer.
 */
export const THINKING_ROOM: Record<Effort, number> = { low: 2_000, medium: 6_000 };

/** `note` asks the model to fix what was wrong with its previous reply. */
type Attempt = { effort: Effort; note?: string };

/**
 * Runs the plan at its reasoning level. One failed attempt earns one retry:
 * at `low` after a timeout or a reply cut short, so the learner still gets an
 * answer in time, otherwise at the same level. A reply the plan's review
 * rejects (wrong language, examples without the word…) gets one corrected
 * retry of its own, told what to fix.
 */
export async function complete(plan: TaskPlan, options: CompleteOptions): Promise<Completion> {
  const now = options.now ?? Date.now;
  const deadline = now() + (options.totalTimeoutMs ?? 26_000);
  const client = new Anthropic({ apiKey: options.apiKey, fetch: options.fetch, maxRetries: 0 });
  let lastKind: 'busy' | 'unavailable' = 'unavailable';
  let retried = false;
  let corrected = false;

  const attempts: Attempt[] = [{ effort: plan.effort }];
  const retry = (effort: Effort) => {
    if (retried) return;
    retried = true;
    attempts.push({ effort });
  };

  for (let index = 0; index < attempts.length; index++) {
    const attempt = attempts[index];
    const remaining = deadline - now();
    if (remaining < 1_500) break;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), Math.min(options.attemptTimeoutMs ?? 18_000, remaining));
    try {
      const message = await client.messages.create(requestBody(plan, attempt.effort, attempt.note), { signal: controller.signal });
      if (message.stop_reason === 'refusal') {
        // Asking again would be declined again; the on-device model answers instead.
        throw new AIFailure('unavailable', `Claude declined the request (${message.stop_details?.category ?? 'no category'})`);
      }
      if (message.stop_reason === 'max_tokens') { retry('low'); continue; }
      const text = message.content.find((block) => block.type === 'text');
      if (!text || text.type !== 'text') { retry(attempt.effort); continue; }
      const content = JSON.parse(text.text);
      const note = plan.review?.(content) ?? null;
      if (note) {
        if (!corrected) {
          corrected = true;
          attempts.splice(index + 1, 0, { effort: attempt.effort, note });
        }
        continue;
      }
      return { model: MODEL, effort: attempt.effort, content: plan.refine ? plan.refine(content) : content };
    } catch (error) {
      if (error instanceof AIFailure) throw error;
      if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
        throw new AIFailure('misconfigured', `Anthropic rejected the API key (${error.status})`);
      }
      if (error instanceof Anthropic.RateLimitError) {
        // This account's limit applies to every attempt, so another one now would only fail again.
        const seconds = Number(error.headers.get('retry-after'));
        throw new AIFailure('busy', 'Rate limited', Number.isFinite(seconds) && seconds > 0 ? seconds : undefined);
      }
      if (error instanceof Anthropic.InternalServerError) {
        // 529 means Anthropic is overloaded; any other 5xx is an outage.
        if (error.status === 529) lastKind = 'busy';
        retry(attempt.effort);
        continue;
      }
      if (error instanceof Anthropic.APIUserAbortError || error instanceof Anthropic.APIConnectionTimeoutError) {
        retry('low');
        continue;
      }
      if (error instanceof Anthropic.APIConnectionError || error instanceof SyntaxError) {
        retry(attempt.effort);
        continue;
      }
      if (error instanceof Anthropic.APIError) {
        // A 400, 404 or 413 means this function sent something wrong; a retry would too.
        throw new AIFailure('misconfigured', `Anthropic refused the request (${error.status}): ${error.message}`);
      }
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
  throw new AIFailure(lastKind, lastKind === 'busy' ? 'Claude is overloaded' : 'Claude did not answer');
}

export function requestBody(plan: TaskPlan, effort: Effort, note?: string): Anthropic.MessageCreateParamsNonStreaming {
  const system = note ? `${note}\n\n${plan.system}` : plan.system;
  return {
    model: MODEL,
    max_tokens: plan.maxTokens + THINKING_ROOM[effort],
    system,
    messages: [{ role: 'user', content: plan.user }],
    thinking: { type: 'adaptive' },
    output_config: { effort, format: { type: 'json_schema', schema: plan.schema } },
  };
}
