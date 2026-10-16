# Salary Management — Requirements

## Goal
ACME's HR Manager tracks salaries for 10,000 employees across several countries in Excel spreadsheets. This app replaces that with a web app focused on salary management: keeping salary records, running monthly payroll and answering questions about how the org pays people.

## User
The HR Manager. There is a single HR login and no other roles.

## Scope (in build order)
1. **Employees (read-only) and salary revisions.** Employees come only from the seed script and Excel import. Their details are never edited, and employees are never deleted. The only change allowed is termination. The employee list is read-only, with search and filters. Each employee's detail page shows their salary revision history, an "Add revision" button and a "Terminate" action that takes a date. A salary revision is immutable and has an effective date. Every revision needs a reason: initial, increment, promotion, correction or other. The current salary is the latest revision effective on or before today. A revision:
   - can't be effective before `joined_on`
   - can't be effective after `terminated_on`
   - can't share an effective date with another revision for the same employee
   - can be dated in the future

   `terminated_on` is the employee's last working day, and they count as terminated from the day after. It can't be earlier than `joined_on`, and it can't fall in a locked month. A future revision doesn't block termination. Any revision dated after `terminated_on` simply never applies. Bank account numbers show only their last 4 digits in the UI.
2. **Insights dashboard.** Shows min, max, average and median salary, headcount and total salary cost, filterable by country, department and job title. Only active employees are counted.
3. **Excel import.** Synchronous, with row-level validation. Valid rows are imported and invalid rows come back in an error report. Import only creates employees. If an employee code already exists, the row is skipped with the reason "already exists", so the same file can be uploaded again safely. Each row's salary becomes the employee's first revision, effective from `joined_on`, with the reason "initial". Department and job title are trimmed and then matched exactly. A row whose country isn't in the system is rejected.
4. **Tax.** One flat tax rate per country, configurable by HR.
5. **Monthly payroll.** Each run is stored with its month as a date (the 1st of the month, e.g. 2026-10-01), and the month is unique. HR picks a month and clicks "Generate payroll":
   - **A new month** creates a run. It must be later than the latest existing run, and no later than the current month. Every entry starts with a bonus and deduction of 0.
   - **The latest month (the open month)** is recalculated in place, after a confirmation dialog:
     - the calculated amounts are refreshed from the current revisions, terminations and tax rates
     - bonuses, deductions and notes that HR entered are kept
     - newly eligible employees are added. No entry is ever removed, because under these rules an employee already in the open month can't stop being eligible (termination can't fall in a locked month).
   - **Older months** are locked (read-only). Corrections go in as a one-time bonus or deduction in a later month.

   A run has one entry for every employee who worked at least one day in that month. The month's salary is the revision in effect on the employee's last day worked in that month, which is the earlier of `terminated_on` and the month's last day.

   Payroll entries are the only stored payroll. Each entry references the salary revision it used (revisions never change) and stores the tax rate, days worked and the calculated amounts, so later revisions or tax-rate changes don't alter locked months. Viewing and exporting read the stored entries and never recalculate. Changes to revisions, terminations or tax rates reach the open month only when HR clicks Recalculate. If any of these, or a newly imported employee, changed after the open month was last generated, the Payroll page shows an "Outdated" badge ("Changes after last generation, please recalculate"), so HR doesn't export and pay with old numbers.

   HR enters the one-time bonus, one-time deduction and an optional note on the Payroll page, and only on entries of the open month. Saving them recalculates only that entry, from its stored monthly amounts and tax rate. Net pay below zero is allowed and flagged, because HR uses this to recover loans and advances.

   The selected month's payroll can be exported to Excel with these columns: employee code, name, full bank account number, days worked, monthly gross, monthly deductions, one-time bonus, one-time deduction, adjustment note, tax and net.

## Definitions
- All amounts are in **USD**. Using one currency makes pay comparable across countries.
- Salary components (base, allowances, deductions) are stored as **annual** amounts.
- Salary = annual gross = base + allowances. Total salary cost = the sum of annual gross across employees.
- Proration factor = days worked in the month / calendar days in the month. Days worked run from the later of `joined_on` and the 1st, to the earlier of `terminated_on` and the month's last day, inclusive.
- Monthly gross = annual gross / 12 × proration factor
- Monthly deductions = annual deductions / 12 × proration factor
- Taxable = monthly gross + one-time bonus
- Tax = country rate × taxable
- Net = taxable − tax − monthly deductions − one-time deduction
- All deductions are taken after tax. One-time amounts are never prorated.
- Rounding: monthly gross, monthly deductions and tax are each rounded to 2 decimal places (half up). Taxable and net are calculated from those rounded values, so the exported columns always add up.

## Deliberately out of scope
| Item | Reason |
|---|---|
| Employee create/edit/delete | Employee data comes from the seed script and import. The focus is salary management. |
| Updating employees or salaries through import | Salary changes are made in the UI as new revisions, which keeps the history accurate. |
| Generic export with filters | HR only needs the monthly payroll export. |
| Local currencies and FX | USD is enough for comparing pay across countries. Multi-currency would touch every calculation. |
| Real tax rules (slabs, exemptions), pre-tax deductions | These differ by country. A flat rate is enough to show gross vs. net. |
| Proration by working days | This would need a holiday calendar for each country. Calendar days are used instead. |
| Encrypting bank account numbers at rest | Only HR uses the app and the UI masks the number. Encryption would add key management to the deployment. |
| Approval workflows, payslips/PDF, leave/attendance | These belong to a full HRMS and aren't needed for salary management. |
| Background jobs for import | At this data size, a synchronous import is fast enough. |

## Known limitations
- Employee details can't be changed after import.
- Termination can't be undone, and its date can't be changed.
- If a raise is backdated into a locked month, that month's payroll stays as it was paid. The app doesn't calculate arrears automatically. HR adds the difference as a one-time bonus in an open month.
- The latest month can be recalculated even after it has been paid. Until the next month's run exists, the confirmation dialog is the only safeguard.
- A salary change in the middle of a month applies to the whole month, using the revision in effect on the last day worked.

## Technical decisions
- Rails app with Postgres. The same Rails app serves the React + Ant Design build.
- RSpec, with features built test-first (TDD).
- Hosted on an Oracle Cloud free VM using Docker, Caddy and DuckDNS.
- A seed script creates 10,000 employees with realistic salary spreads per country and job title.
