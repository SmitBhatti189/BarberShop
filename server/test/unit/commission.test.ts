import { describe, expect, it } from 'vitest';
import { commissionAmount, effectiveRate } from '../../src/modules/compensation/commission.calculator.js';
import { fromPaise, toPaise } from '../../src/shared/money.js';

describe('effectiveRate (owner rule 2026-11-24)', () => {
  it('uses the employee’s own rate whenever one is set', () => {
    expect(effectiveRate({ specificRatePct: '40.00', hasMonthlySalary: false, salonDefaultPct: '10.00' })).toEqual({
      ratePct: '40.00',
      source: 'SPECIFIC',
    });
    expect(effectiveRate({ specificRatePct: '5.00', hasMonthlySalary: true, salonDefaultPct: '10.00' })).toEqual({
      ratePct: '5.00',
      source: 'SPECIFIC',
    });
  });

  it('falls back to the salon default only for employees without a salary', () => {
    expect(effectiveRate({ specificRatePct: null, hasMonthlySalary: false, salonDefaultPct: '10.00' })).toEqual({
      ratePct: '10.00',
      source: 'DEFAULT',
    });
    expect(effectiveRate({ specificRatePct: null, hasMonthlySalary: true, salonDefaultPct: '10.00' })).toEqual({
      ratePct: null,
      source: 'NONE',
    });
  });

  it('keeps an explicit 0 % as a real choice', () => {
    expect(effectiveRate({ specificRatePct: '0.00', hasMonthlySalary: false, salonDefaultPct: '10.00' }).ratePct).toBe('0.00');
  });
});

describe('commissionAmount', () => {
  it('matches the requirement example: ₹200 × 40 % + ₹100 × 30 % = ₹110', () => {
    const total = toPaise(commissionAmount('200.00', '40.00')) + toPaise(commissionAmount('100.00', '30.00'));
    expect(fromPaise(total)).toBe('110.00');
  });

  it('rounds half up to the paisa and pays nothing without a rate', () => {
    expect(commissionAmount('99.99', '12.50')).toBe('12.50');
    expect(commissionAmount('500.00', null)).toBe('0.00');
  });
});
