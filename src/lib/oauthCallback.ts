export type OAuthCallbackParams = {
  accessToken: string | null;
  code: string | null;
  error: string | null;
  errorCode: string | null;
  identityId: string | null;
  refreshToken: string | null;
};

export function parseOAuthCallbackUrl(url: string): OAuthCallbackParams {
  const params = new URLSearchParams(extractQueryAndHash(url));

  return {
    accessToken: params.get('access_token'),
    code: params.get('code'),
    error: params.get('error_description') ?? params.get('error'),
    errorCode: params.get('error_code'),
    identityId: params.get('identity_id'),
    refreshToken: params.get('refresh_token'),
  };
}

function extractQueryAndHash(url: string): string {
  const queryIndex = url.indexOf('?');
  const hashIndex = url.indexOf('#');
  const parts: string[] = [];

  if (queryIndex >= 0) {
    const queryEnd = hashIndex > queryIndex ? hashIndex : url.length;
    parts.push(url.slice(queryIndex + 1, queryEnd));
  }

  if (hashIndex >= 0) {
    parts.push(url.slice(hashIndex + 1));
  }

  return parts.filter(Boolean).join('&');
}
