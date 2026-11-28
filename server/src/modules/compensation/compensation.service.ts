import type { Db } from '../../db/database.js';
import { withTransaction } from '../../db/transaction.js';
import { BusinessRuleError, NotFoundError } from '../../shared/errors.js';
import type { Principal } from '../auth/principal.repository.js';
import { sellingPrice } from '../inventory/inventory.service.js';
import { effectiveRate } from './commission.calculator.js';
import * as repo from './compensation.repository.js';
import type { PaySummaryDto, SavePayInput, StaffPayDto } from './compensation.schemas.js';

/** "10.00" and "10" are the same rate. */
const sameRate = (a: string, b: string) => Number(a) === Number(b);

/**
 * Pay setup: salon default %, each employee's monthly salary and their own
 * commission rates per service and product. Every change closes the old
 * entry and opens a new one, so the history of who earned what, when, is kept.
 */
export class CompensationService {
  constructor(private readonly db: Db) {}

  async salonDefault(): Promise<{ defaultCommissionPct: string }> {
    return { defaultCommissionPct: await repo.salonDefaultPct(this.db) };
  }

  async setSalonDefault(pct: string): Promise<{ defaultCommissionPct: string }> {
    await repo.setSalonDefaultPct(this.db, pct);
    return this.salonDefault();
  }

  async summaries(): Promise<PaySummaryDto[]> {
    return repo.listPaySummaries(this.db);
  }

  async staffPay(staffId: number): Promise<StaffPayDto> {
    const staff = await repo.findStaffBasics(this.db, staffId);
    if (!staff) throw new NotFoundError('Employee');
    const [salary, rules, defaultPct, services, products] = await Promise.all([
      repo.currentSalary(this.db, staffId),
      repo.currentRules(this.db, staffId),
      repo.salonDefaultPct(this.db),
      repo.activeServices(this.db),
      repo.activeProducts(this.db),
    ]);
    const hasMonthlySalary = Boolean(salary);
    const ruleFor = (type: 'SERVICE' | 'PRODUCT', id: number) =>
      rules.find((r) => r.itemType === type && r.itemId === id)?.ratePct ?? null;

    const item = (type: 'SERVICE' | 'PRODUCT', id: number, name: string, detail: string | null, price: string) => {
      const specific = ruleFor(type, id);
      const effective = effectiveRate({ specificRatePct: specific, hasMonthlySalary, salonDefaultPct: defaultPct });
      return {
        itemId: id,
        name,
        detail,
        price,
        ratePct: specific,
        effectiveRatePct: effective.ratePct,
        source: effective.source,
      };
    };

    return {
      staff: { id: staff.id, fullName: staff.fullName, roleName: staff.roleName, performsServices: staff.performsServices },
      monthlySalary: salary?.monthlySalary ?? null,
      salonDefaultPct: defaultPct,
      services: services.map((s) => item('SERVICE', s.id, s.name, s.category, s.price)),
      products: products.map((p) =>
        item(
          'PRODUCT',
          p.id,
          p.name,
          [p.brand, p.category].filter(Boolean).join(' · ') || null,
          sellingPrice(p.mrp, p.discountPct),
        ),
      ),
    };
  }

  /**
   * Saves salary and the listed rates in one transaction. The employee row is
   * locked first, and history boundaries use the clock *after* the lock, so
   * two managers saving the same employee at once can't interleave.
   */
  async savePay(actor: Principal, staffId: number, input: SavePayInput): Promise<StaffPayDto> {
    const staff = await repo.findStaffBasics(this.db, staffId);
    if (!staff) throw new NotFoundError('Employee');
    if (!staff.isActive) throw new BusinessRuleError('STAFF_INACTIVE', 'Reactivate this employee before changing their pay.');

    for (const type of ['SERVICE', 'PRODUCT'] as const) {
      const ids = input.rates.filter((r) => r.itemType === type).map((r) => r.itemId);
      const found = await repo.activeItemIds(this.db, type, ids);
      const missing = ids.filter((id) => !found.has(id));
      if (missing.length > 0) {
        throw new BusinessRuleError(
          'ITEM_NOT_AVAILABLE',
          `Some ${type === 'SERVICE' ? 'services' : 'products'} no longer exist or are inactive. Reload and try again.`,
          { itemType: type, itemIds: missing },
        );
      }
    }

    await withTransaction(this.db, async (trx) => {
      await repo.lockStaff(trx, staffId);
      const at = await repo.clockNow(trx);

      const salary = await repo.currentSalary(trx, staffId);
      const salaryChanged =
        (salary === undefined) !== (input.monthlySalary === null) ||
        (salary !== undefined && input.monthlySalary !== null && !sameRate(salary.monthlySalary, input.monthlySalary));
      if (salaryChanged) {
        if (salary) await repo.closeSalary(trx, salary.id, at);
        if (input.monthlySalary !== null) await repo.insertSalary(trx, staffId, input.monthlySalary, at, actor.staffId);
      }

      const rules = await repo.currentRules(trx, staffId);
      for (const r of input.rates) {
        const current = rules.find((c) => c.itemType === r.itemType && c.itemId === r.itemId);
        if (r.ratePct === null) {
          if (current) await repo.closeRule(trx, current.id, at);
        } else if (!current || !sameRate(current.ratePct, r.ratePct)) {
          if (current) await repo.closeRule(trx, current.id, at);
          await repo.insertRule(trx, { staffId, itemType: r.itemType, itemId: r.itemId, ratePct: r.ratePct, at, by: actor.staffId });
        }
      }
    });
    return this.staffPay(staffId);
  }
}
