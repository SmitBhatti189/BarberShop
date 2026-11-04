import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { Db } from '../../db/database.js';
import { withTransaction } from '../../db/transaction.js';
import { AppError, UnauthorizedError } from '../../shared/errors.js';
import * as repo from './auth.repository.js';
import type { LoginBody, MeDto, TokenPairDto } from './auth.schemas.js';
import { LoginThrottle } from './login-throttle.js';
import { hashPassword, needsRehash, verifyPassword } from './password.js';
import { findActivePrincipal, type Principal } from './principal.repository.js';

export interface AuthServiceDeps {
  db: Db;
  signAccessToken: (claims: { sub: string; sid: number }) => string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlDays: number;
  throttle?: LoginThrottle;
}

const INVALID_CREDENTIALS = 'Invalid username or password';

/**
 * Login, refresh-token rotation and logout.
 *
 * Refresh tokens are random 256-bit values; only their SHA-256 hash is stored.
 * Every refresh revokes the presented token and issues a new one in the same
 * "family". Presenting an already-revoked token means it was stolen or
 * replayed, so the entire family is revoked (forces a fresh login).
 */
export class AuthService {
  private readonly throttle: LoginThrottle;
  private dummyHash: Promise<string> | undefined;

  constructor(private readonly deps: AuthServiceDeps) {
    this.throttle = deps.throttle ?? new LoginThrottle();
  }

  async login(input: LoginBody, clientIp: string): Promise<TokenPairDto> {
    const throttleKey = `${input.username.toLowerCase()}|${clientIp}`;
    if (this.throttle.isBlocked(throttleKey)) {
      throw new AppError(429, 'TOO_MANY_ATTEMPTS', 'Too many failed login attempts. Try again later.');
    }

    const candidate = await repo.findLoginCandidate(this.deps.db, input.username);
    // Always run one argon2 verification so response time does not reveal whether the username exists.
    const valid = candidate
      ? await verifyPassword(candidate.passwordHash, input.password)
      : await verifyPassword(await this.getDummyHash(), input.password).then(() => false);

    if (!candidate || !valid || !candidate.isActive) {
      this.throttle.recordFailure(throttleKey);
      throw new AppError(401, 'INVALID_CREDENTIALS', INVALID_CREDENTIALS);
    }
    this.throttle.reset(throttleKey);

    if (needsRehash(candidate.passwordHash)) {
      await repo.updatePasswordHash(this.deps.db, candidate.id, await hashPassword(input.password));
    }

    const refreshToken = newRefreshToken();
    const sessionId = await repo.insertSession(this.deps.db, {
      staffId: candidate.id,
      tokenHash: hashToken(refreshToken),
      familyId: randomUUID(),
      expiresAt: this.refreshExpiry(),
      deviceLabel: input.deviceLabel ?? null,
    });
    return this.tokenPair(candidate.id, sessionId, refreshToken);
  }

  async refresh(refreshToken: string): Promise<TokenPairDto> {
    const result = await withTransaction(this.deps.db, async (trx) => {
      const session = await repo.findSessionForRefreshForUpdate(trx, hashToken(refreshToken));
      if (!session) return { error: 'invalid' as const };
      if (session.revokedAt) {
        await repo.revokeFamily(trx, session.familyId);
        return { error: 'reused' as const };
      }
      if (session.expiresAt.getTime() <= Date.now() || !session.staffActive) {
        await repo.revokeSession(trx, session.id);
        return { error: 'expired' as const };
      }

      await repo.revokeSession(trx, session.id);
      const next = newRefreshToken();
      const sessionId = await repo.insertSession(trx, {
        staffId: session.staffId,
        tokenHash: hashToken(next),
        familyId: session.familyId,
        expiresAt: this.refreshExpiry(),
        deviceLabel: session.deviceLabel,
      });
      return { staffId: session.staffId, sessionId, refreshToken: next };
    });
    // Revocations above must commit even though the caller gets a 401, so we
    // decide the error only after the transaction has finished.
    if ('error' in result) throw new UnauthorizedError('Session expired. Please log in again.');
    return this.tokenPair(result.staffId, result.sessionId, result.refreshToken);
  }

  async logout(principal: Principal): Promise<void> {
    await repo.revokeSession(this.deps.db, principal.sessionId);
  }

  private async tokenPair(staffId: number, sessionId: number, refreshToken: string): Promise<TokenPairDto> {
    const principal = await findActivePrincipal(this.deps.db, staffId, sessionId);
    if (!principal) throw new UnauthorizedError();
    return {
      accessToken: this.deps.signAccessToken({ sub: String(staffId), sid: sessionId }),
      refreshToken,
      expiresIn: this.deps.accessTokenTtlSeconds,
      user: toMeDto(principal),
    };
  }

  private refreshExpiry(): Date {
    return new Date(Date.now() + this.deps.refreshTokenTtlDays * 86_400_000);
  }

  private getDummyHash(): Promise<string> {
    this.dummyHash ??= hashPassword(randomBytes(16).toString('hex'));
    return this.dummyHash;
  }
}

export function toMeDto(p: Principal): MeDto {
  return {
    id: p.staffId,
    fullName: p.fullName,
    branchId: p.branchId,
    roleId: p.roleId,
    permissions: [...p.permissions].sort(),
  };
}

function newRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
