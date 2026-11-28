import { fromPaise, percentOf, rateToBasisPoints, toPaise } from '../../shared/money.js';

export type RateSource = 'SPECIFIC' | 'DEFAULT' | 'NONE';

export interface EffectiveRate {
  /** "10.00", or null when the employee earns no commission on this item. */
  ratePct: string | null;
  source: RateSource;
}

/**
 * THE commission rate rule (owner decision 2026-11-24). Everything that needs
 * an employee's rate for a service or product — the pay page now, billing
 * later — calls this one function.
 *
 * 1. A specific rate set for this employee and item always wins.
 * 2. Otherwise, an employee with NO monthly salary gets the salon default.
 * 3. Otherwise (salaried, no specific rate) there is no commission.
 */
export function effectiveRate(input: {
  specificRatePct: string | null;
  hasMonthlySalary: boolean;
  salonDefaultPct: string;
}): EffectiveRate {
  if (input.specificRatePct !== null) return { ratePct: input.specificRatePct, source: 'SPECIFIC' };
  if (!input.hasMonthlySalary) return { ratePct: input.salonDefaultPct, source: 'DEFAULT' };
  return { ratePct: null, source: 'NONE' };
}

/** Commission on a line: basis × rate, rounded half-up to the paisa. */
export function commissionAmount(basis: string, ratePct: string | null): string {
  if (ratePct === null) return '0.00';
  return fromPaise(percentOf(toPaise(basis), rateToBasisPoints(ratePct)));
}
