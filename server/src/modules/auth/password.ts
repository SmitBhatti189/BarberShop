import argon2 from 'argon2';

/**
 * Password hashing (argon2id, OWASP-recommended parameters).
 * Hashes embed their own salt and parameters, so they can be strengthened
 * later without invalidating existing passwords (`needsRehash`).
 */
const OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19_456, // 19 MiB
  timeCost: 2,
  parallelism: 1,
} as const;

export function hashPassword(plain: string): Promise<string> {
  return argon2.hash(plain, OPTIONS);
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plain);
  } catch {
    return false; // malformed hash ⇒ treat as mismatch, never throw to the caller
  }
}

export function needsRehash(hash: string): boolean {
  return argon2.needsRehash(hash, OPTIONS);
}
