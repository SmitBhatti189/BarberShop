/**
 * Brute-force protection for login: after `maxFailures` failed attempts for
 * the same key (username + client IP) within `windowMs`, further attempts are
 * refused until the window passes. In-memory is sufficient for a single API
 * process; move to the database or Redis if the API is ever scaled out.
 * Node runs this on one thread, so the Map needs no extra locking.
 */
export class LoginThrottle {
  private readonly failures = new Map<string, { count: number; firstAt: number }>();

  constructor(
    private readonly maxFailures = 5,
    private readonly windowMs = 15 * 60 * 1000,
    private readonly now: () => number = Date.now,
  ) {}

  isBlocked(key: string): boolean {
    const entry = this.current(key);
    return entry !== undefined && entry.count >= this.maxFailures;
  }

  recordFailure(key: string): void {
    const entry = this.current(key);
    if (entry) entry.count += 1;
    else this.failures.set(key, { count: 1, firstAt: this.now() });
    if (this.failures.size > 10_000) this.prune();
  }

  reset(key: string): void {
    this.failures.delete(key);
  }

  private current(key: string) {
    const entry = this.failures.get(key);
    if (entry && this.now() - entry.firstAt > this.windowMs) {
      this.failures.delete(key);
      return undefined;
    }
    return entry;
  }

  private prune(): void {
    for (const key of this.failures.keys()) this.current(key);
  }
}
