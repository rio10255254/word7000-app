type AppleFullName = {
  familyName?: string | null;
  givenName?: string | null;
  middleName?: string | null;
  namePrefix?: string | null;
  nameSuffix?: string | null;
  nickname?: string | null;
};

export type AppleCredentialMetadata = {
  apple_user?: string;
  email?: string;
  family_name?: string;
  full_name?: string;
  given_name?: string;
};

const nonceCharacters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';

export function createAppleNonce(length = 32): string {
  const cryptoObject = globalThis.crypto;

  if (cryptoObject?.getRandomValues) {
    const bytes = new Uint8Array(length);
    cryptoObject.getRandomValues(bytes);
    return Array.from(bytes, (byte) => nonceCharacters[byte % nonceCharacters.length]).join('');
  }

  return Array.from({ length }, () => nonceCharacters[Math.floor(Math.random() * nonceCharacters.length)]).join('');
}

function compactNamePart(value?: string | null): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

export function appleCredentialMetadata(
  fullName?: AppleFullName | null,
  email?: string | null,
  appleUser?: string | null,
): AppleCredentialMetadata {
  const givenName = compactNamePart(fullName?.givenName);
  const familyName = compactNamePart(fullName?.familyName);
  const fullNameText = [givenName, familyName].filter(Boolean).join(' ').trim();
  const normalizedEmail = compactNamePart(email);
  const normalizedAppleUser = compactNamePart(appleUser);

  return {
    ...(normalizedAppleUser ? { apple_user: normalizedAppleUser } : {}),
    ...(normalizedEmail ? { email: normalizedEmail } : {}),
    ...(familyName ? { family_name: familyName } : {}),
    ...(fullNameText ? { full_name: fullNameText } : {}),
    ...(givenName ? { given_name: givenName } : {}),
  };
}
