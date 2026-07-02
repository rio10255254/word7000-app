const DEFAULT_WEB_ORIGIN = 'https://word7000-app.rio10255254.workers.dev';

export const appInfoLinks = {
  privacy: buildHostedAppUrl('/privacy.html'),
  support: buildHostedAppUrl('/support.html'),
};

export function buildHostedAppUrl(path: string, origin = process.env.EXPO_PUBLIC_WORD7000_WEB_ORIGIN ?? DEFAULT_WEB_ORIGIN): string {
  const normalizedOrigin = origin.trim().replace(/\/+$/, '') || DEFAULT_WEB_ORIGIN;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${normalizedOrigin}${normalizedPath}`;
}
