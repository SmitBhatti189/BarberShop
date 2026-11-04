/**
 * Money helpers. All arithmetic is done on integer paise (1 ₹ = 100 paise) so
 * there are no floating-point errors. PostgreSQL NUMERIC values arrive from
 * `pg` as strings ("123.45") and are converted with `toPaise`; responses are
 * converted back with `fromPaise`.
 *
 * Rates are handled as integer basis points (40.00 % = 4000 bp).
 */

export type Paise = number;

const DECIMAL_RE = /^(-)?(\d+)(?:\.(\d{1,2}))?$/;

export function toPaise(value: string | number): Paise {
  const text = typeof value === 'number' ? value.toFixed(2) : value.trim();
  const match = DECIMAL_RE.exec(text);
  if (!match) throw new RangeError(`Invalid money value: ${String(value)}`);
  const [, sign, rupees, fraction = ''] = match;
  const paise = Number(rupees) * 100 + Number(fraction.padEnd(2, '0'));
  if (!Number.isSafeInteger(paise)) throw new RangeError(`Money value out of range: ${String(value)}`);
  return sign && paise !== 0 ? -paise : paise;
}

export function fromPaise(paise: Paise): string {
  assertInteger(paise);
  const sign = paise < 0 ? '-' : '';
  const abs = Math.abs(paise);
  return `${sign}${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
}

export function rateToBasisPoints(rate: string | number): number {
  // A rate has the same 2-decimal shape as money: "40.00" → 4000.
  const bp = toPaise(rate);
  if (bp < 0 || bp > 10_000) throw new RangeError(`Rate must be between 0 and 100: ${String(rate)}`);
  return bp;
}

/** Integer division rounding half away from zero. */
export function divRoundHalfUp(numerator: number, denominator: number): number {
  if (denominator <= 0) throw new RangeError('denominator must be positive');
  const sign = numerator < 0 ? -1 : 1;
  return sign * Math.floor((Math.abs(numerator) * 2 + denominator) / (denominator * 2));
}

/** `basis × rate %`, rounded half-up to the paisa. Used for commission. */
export function percentOf(basis: Paise, rateBasisPoints: number): Paise {
  assertInteger(basis);
  return divRoundHalfUp(basis * rateBasisPoints, 10_000);
}

/**
 * Splits `total` across `weights` proportionally using the largest-remainder
 * method, so the parts always sum exactly to `total` (no lost paisa). Used to
 * spread bill-level discounts across lines.
 */
export function allocateProRata(total: Paise, weights: readonly Paise[]): Paise[] {
  assertInteger(total);
  if (total < 0) throw new RangeError('total must not be negative');
  const weightSum = weights.reduce((sum, w) => sum + w, 0);
  if (weights.length === 0 || weightSum <= 0) {
    if (total === 0) return weights.map(() => 0);
    throw new RangeError('cannot allocate a non-zero amount over zero weights');
  }
  if (weights.some((w) => w < 0)) throw new RangeError('weights must not be negative');

  const shares = weights.map((w, index) => {
    const exact = total * w;
    if (!Number.isSafeInteger(exact)) throw new RangeError('allocation amounts too large');
    return { index, floor: Math.floor(exact / weightSum), remainder: exact % weightSum };
  });
  let leftover = total - shares.reduce((sum, s) => sum + s.floor, 0);
  // Largest remainder first; ties go to the earlier line for determinism.
  const order = [...shares].sort((a, b) => b.remainder - a.remainder || a.index - b.index);
  for (const share of order) {
    if (leftover === 0) break;
    share.floor += 1;
    leftover -= 1;
  }
  return shares.map((s) => s.floor);
}

/**
 * Customer bill round-off (owner rule): to the nearest `unit`, where a
 * remainder up to and including half the unit rounds DOWN and anything above
 * rounds UP. With unit ₹10: ₹525 → ₹520 (−5), ₹526 → ₹530 (+4).
 * Returns the signed adjustment to add to the total. `unit` 0 disables it.
 */
export function billRoundOff(total: Paise, unit: Paise): Paise {
  assertInteger(total);
  if (unit === 0 || total <= 0) return 0;
  const remainder = total % unit;
  if (remainder === 0) return 0;
  return remainder * 2 <= unit ? -remainder : unit - remainder;
}

/**
 * Staff payout round-off: always UP to the next `unit` (₹113 → ₹120).
 * Returns the non-negative amount added. Non-positive balances get nothing.
 */
export function payoutRoundUp(amount: Paise, unit: Paise): Paise {
  assertInteger(amount);
  if (unit === 0 || amount <= 0) return 0;
  const remainder = amount % unit;
  return remainder === 0 ? 0 : unit - remainder;
}

function assertInteger(value: number): void {
  if (!Number.isSafeInteger(value)) throw new RangeError(`Expected integer paise, got ${value}`);
}
