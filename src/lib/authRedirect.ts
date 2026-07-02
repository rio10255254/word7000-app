type BrowserLocationLike = {
  origin?: string;
  pathname?: string;
};

const OAUTH_CALLBACK_PATH = 'auth/callback';

export function authRedirectTo(locationLike: BrowserLocationLike | null | undefined): string | undefined {
  const origin = locationLike?.origin?.trim();
  if (!origin) {
    return undefined;
  }

  const pathname = locationLike?.pathname?.startsWith('/') ? locationLike.pathname : '/';
  return `${origin}${pathname}`;
}

export function nativeAuthRedirectTo(scheme: string): string {
  return `${scheme.replace(/:\/+$/, '')}://${OAUTH_CALLBACK_PATH}`;
}
