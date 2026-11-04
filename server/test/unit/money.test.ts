import { describe, expect, it } from 'vitest';
import {
  allocateProRata,
  billRoundOff,
  divRoundHalfUp,
  fromPaise,
  payoutRoundUp,
  percentOf,
  rateToBasisPoints,
  toPaise,
} from '../../src/shared/money.js';

describe('toPaise / fromPaise', () => {
  it('parses NUMERIC strings exactly', () => {
    expect(toPaise('0')).toBe(0);
    expect(toPaise('200')).toBe(20_000);
    expect(toPaise('199.99')).toBe(19_999);
    expect(toPaise('0.1')).toBe(10);
    expect(toPaise('-5.50')).toBe(-550);
    expect(toPaise(0.1 + 0.2)).toBe(30); // float noise is removed
  });

  it('rejects malformed or over-precise values', () => {
    expect(() => toPaise('12.345')).toThrow(RangeError);
    expect(() => toPaise('abc')).toThrow(RangeError);
    expect(() => toPaise('')).toThrow(RangeError);
  });

  it('formats back to 2-decimal strings', () => {
    expect(fromPaise(52_000)).toBe('520.00');
    expect(fromPaise(1_980)).toBe('19.80');
    expect(fromPaise(5)).toBe('0.05');
    expect(fromPaise(-700)).toBe('-7.00');
    expect(() => fromPaise(1.5)).toThrow(RangeError);
  });
});

describe('rates and percentages', () => {
  it('converts rates to basis points within 0–100 %', () => {
    expect(rateToBasisPoints('40.00')).toBe(4000);
    expect(rateToBasisPoints('12.5')).toBe(1250);
    expect(() => rateToBasisPoints('100.01')).toThrow(RangeError);
    expect(() => rateToBasisPoints('-1')).toThrow(RangeError);
  });

  it('rounds half up', () => {
    expect(divRoundHalfUp(5, 2)).toBe(3);
    expect(divRoundHalfUp(4, 2)).toBe(2);
    expect(divRoundHalfUp(-5, 2)).toBe(-3);
  });

  it('computes the requirement example: ₹200 × 40 % + ₹100 × 30 % = ₹110', () => {
    const haircut = percentOf(toPaise('200'), rateToBasisPoints('40'));
    const beard = percentOf(toPaise('100'), rateToBasisPoints('30'));
    expect(fromPaise(haircut + beard)).toBe('110.00');
  });

  it('rounds commission to the paisa', () => {
    // ₹99.99 × 12.5 % = 12.49875 → ₹12.50
    expect(percentOf(9_999, 1250)).toBe(1_250);
  });
});

describe('allocateProRata', () => {
  it('splits proportionally and always sums to the total', () => {
    // ₹52 extra discount over Haircut ₹200, Beard ₹100, Shampoo ₹220.
    const parts = allocateProRata(5_200, [20_000, 10_000, 22_000]);
    expect(parts).toEqual([2_000, 1_000, 2_200]);
  });

  it('distributes leftover paise by largest remainder', () => {
    const parts = allocateProRata(100, [1, 1, 1]);
    expect(parts.reduce((a, b) => a + b, 0)).toBe(100);
    expect(parts).toEqual([34, 33, 33]);
  });

  it('handles zero totals and rejects impossible allocations', () => {
    expect(allocateProRata(0, [0, 0])).toEqual([0, 0]);
    expect(() => allocateProRata(10, [0, 0])).toThrow(RangeError);
    expect(() => allocateProRata(-1, [1])).toThrow(RangeError);
  });
});

describe('billRoundOff (owner rule: last digit 1–5 down, 6–9 up)', () => {
  const ten = toPaise('10');
  it.each([
    ['520', '0.00'],
    ['521', '-1.00'],
    ['525', '-5.00'],
    ['526', '4.00'],
    ['529', '1.00'],
    ['525.50', '4.50'],
    ['527', '3.00'],
  ])('₹%s → round-off %s', (total, expected) => {
    expect(fromPaise(billRoundOff(toPaise(total), ten))).toBe(expected);
  });

  it('is disabled with unit 0 and never applies to zero bills', () => {
    expect(billRoundOff(toPaise('527'), 0)).toBe(0);
    expect(billRoundOff(0, ten)).toBe(0);
  });

  it('supports a ₹5 unit', () => {
    expect(fromPaise(billRoundOff(toPaise('522.50'), toPaise('5')))).toBe('-2.50');
    expect(fromPaise(billRoundOff(toPaise('523'), toPaise('5')))).toBe('2.00');
  });
});

describe('payoutRoundUp', () => {
  const ten = toPaise('10');
  it('always rounds staff payouts up', () => {
    expect(fromPaise(payoutRoundUp(toPaise('113'), ten))).toBe('7.00');
    expect(fromPaise(payoutRoundUp(toPaise('119.99'), ten))).toBe('0.01');
    expect(payoutRoundUp(toPaise('120'), ten)).toBe(0);
  });

  it('gives nothing for zero or negative balances', () => {
    expect(payoutRoundUp(0, ten)).toBe(0);
    expect(payoutRoundUp(toPaise('-50'), ten)).toBe(0);
  });
});
