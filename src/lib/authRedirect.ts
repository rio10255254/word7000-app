type BrowserLocationLike = {
  origin?: string;
  pathname?: string;
};

export function authRedirectTo(locationLike: BrowserLocationLike | null | undefined): string | undefined {
  const origin = locationLike?.origin?.trim();
  if (!origin) {
    return undefined;
  }

  const pathname = locationLike?.pathname?.startsWith('/') ? locationLike.pathname : '/';
  return `${origin}${pathname}`;
}
