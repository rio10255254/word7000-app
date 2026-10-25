import type { TaskPlan } from './tasks.ts';

export const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

export type Fetch = (input: string, init: RequestInit) => Promise<Response>;

export interface Completion {
  model: string;
  content: unknown;
}

/** Why no model answered. `busy` and `unavailable` let the app fall back to the on-device model. */
export class GroqFailure extends Error {
  constructor(readonly kind: 'busy' | 'unavailable' | 'misconfigured', message: string, readonly retryAfter?: number) {
    super(message);
  }
}

export interface CompleteOptions {
  apiKey: string;
  fetch?: Fetch;
  /** Per model, so a stalled model still leaves time for the next one. */
  attemptTimeoutMs?: number;
  totalTimeoutMs?: number;
  now?: () => number;
}

/**
 * Runs the plan on its first model and moves to the next one when a model is
 * rate limited, overloaded, slow or returns something that is not the schema.
 * The two models have separate Groq rate limits, so this also spreads load.
 */
export async function complete(plan: TaskPlan, options: CompleteOptions): Promise<Completion> {
  const fetchImpl = options.fetch ?? fetch;
  const now = options.now ?? Date.now;
  const deadline = now() + (options.totalTimeoutMs ?? 24_000);
  let lastKind: 'busy' | 'unavailable' = 'unavailable';
  let retryAfter: number | undefined;

  // A reply in the wrong language earns that model one corrected retry.
  const attempts: { model: string; corrective: boolean }[] = plan.models.map((model) => ({ model, corrective: false }));
  let retried = false;

  for (let index = 0; index < attempts.length; index++) {
    const { model, corrective } = attempts[index];
    const remaining = deadline - now();
    if (remaining < 1_500) break;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), Math.min(options.attemptTimeoutMs ?? 14_000, remaining));
    try {
      const response = await fetchImpl(GROQ_URL, {
        method: 'POST',
        headers: { Authorization: `Bearer ${options.apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody(plan, model, corrective)),
        signal: controller.signal,
      });
      if (response.status === 401 || response.status === 403) {
        throw new GroqFailure('misconfigured', `Groq rejected the API key (${response.status})`);
      }
      if (!response.ok) {
        if (response.status === 429) {
          lastKind = 'busy';
          const seconds = Number(response.headers.get('retry-after'));
          if (Number.isFinite(seconds) && seconds > 0) retryAfter = Math.max(retryAfter ?? 0, seconds);
        }
        // 400 here is almost always a reply that failed schema validation;
        // the other model gets a turn rather than the learner seeing an error.
        await response.body?.cancel();
        continue;
      }
      const payload = await response.json() as { choices?: { message?: { content?: string } }[] };
      const raw = payload.choices?.[0]?.message?.content;
      if (typeof raw !== 'string') continue;
      const content = JSON.parse(raw);
      if (plan.accept && !plan.accept(content)) {
        if (!retried) {
          retried = true;
          attempts.splice(index + 1, 0, { model, corrective: true });
        }
        continue;
      }
      return { model, content };
    } catch (error) {
      if (error instanceof GroqFailure) throw error;
      // Timeout, network error or malformed JSON: try the next model.
    } finally {
      clearTimeout(timer);
    }
  }
  throw new GroqFailure(lastKind, lastKind === 'busy' ? 'Every model is rate limited' : 'No model answered', retryAfter);
}

export function requestBody(plan: TaskPlan, model: string, corrective = false): Record<string, unknown> {
  const system = corrective && plan.retryNote ? `${plan.retryNote}\n\n${plan.system}` : plan.system;
  return {
    model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: plan.user },
    ],
    temperature: 0.3,
    max_completion_tokens: plan.maxTokens,
    // Low effort keeps replies quick; these tasks need care, not long proofs.
    reasoning_effort: 'low',
    include_reasoning: false,
    response_format: { type: 'json_schema', json_schema: { name: 'reply', strict: true, schema: plan.schema } },
  };
}
