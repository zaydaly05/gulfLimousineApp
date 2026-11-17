// Checks config/ai without revealing it: is a key present, does it look
// like a Google API key, and does Gemini accept it for the configured model.

export const DEFAULT_MODEL = 'gemini-flash-latest';

export function describeAiConfig(data) {
  const key = typeof data?.geminiApiKey === 'string' ? data.geminiApiKey.trim() : '';
  const model = typeof data?.geminiModel === 'string' && data.geminiModel.trim()
    ? data.geminiModel.trim()
    : DEFAULT_MODEL;
  return {
    key,
    report: {
      documentExists: Boolean(data),
      keyPresent: key.length > 0,
      // Google API keys are 39 characters starting "AIza".
      keyLooksValid: /^AIza[0-9A-Za-z_-]{35}$/.test(key),
      keyHasSpaces: typeof data?.geminiApiKey === 'string' && data.geminiApiKey !== key,
      model,
    },
  };
}

/** Asks Gemini to describe the model; costs no tokens. */
export async function checkGeminiKey(key, model, fetchImpl = fetch) {
  try {
    const r = await fetchImpl(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}`,
      { headers: { 'x-goog-api-key': key } },
    );
    return r.ok ? 'accepted' : `rejected (HTTP ${r.status})`;
  } catch {
    return 'unreachable';
  }
}
