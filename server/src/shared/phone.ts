/**
 * Indian mobile numbers, stored as the plain 10-digit number so the same
 * person is found however the number was typed ("+91 98765 43210",
 * "098765-43210", "9876543210" all become "9876543210").
 */
export function normalizeMobile(input: string): string | null {
  let digits = input.replace(/\D/g, '');
  if (digits.length === 12 && digits.startsWith('91')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
  return /^[6-9]\d{9}$/.test(digits) ? digits : null;
}
