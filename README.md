# Salary Management

[![CI](https://github.com/mitkush/salary-management/actions/workflows/ci.yml/badge.svg)](https://github.com/mitkush/salary-management/actions/workflows/ci.yml)

A web app for ACME's HR Manager to manage salaries for about 10,000 employees across several countries. It replaces the spreadsheets HR uses today, and answers questions about how the organisation pays people.

**Live demo:** _added after deployment_ · **Video walkthrough:** _added after deployment_

## Features

- **Dashboard:**
  - Headcount, annual and monthly salary cost, and average, median, lowest and highest salary, as of the end of any month (default: last month).
  - Filters by country, department and job title.
  - A donut of salary cost by country or department.
  - 12-month trends for salary cost and for joiners against leavers.
- **Employees:**
  - A searchable, filterable, paginated list.
  - A detail page with the full salary history.
  - Add a salary revision. Revisions can't be changed after saving; they're replaced by newer ones.
  - Terminate an employee, with a last working day.
  - Bank account numbers are always masked.
- **Excel import:**
  - Download a template and upload `.xlsx` files up to 5 MB.
  - Every row is checked: valid rows are created, and problem rows come back with their row number and reason.
  - Re-uploading the same file is safe.
- **Payroll:**
  - Generate a month: only the next month can be generated, paid months lock, and the latest month can be recalculated.
  - Pay is prorated by calendar days for joiners and leavers. Tax is a flat rate per country.
  - One-time bonuses, deductions and notes can be added, and net pay can go negative (for loan recovery).
  - An "outdated" warning when salaries or rates changed after the last generation.
  - Excel export with the full bank account numbers.
- **Tax rates:** one flat rate per country, edited as a percentage.
- **Login:** a single HR account with a session cookie and CSRF protection. Login attempts are rate limited.

What's in scope, what's deliberately left out, and the known limitations are all in the [requirements](docs/requirements.md).

## Screenshots

_Screenshots of the dashboard, employee list and detail, import and payroll pages will be added here._

## Run with Docker

Requires Docker with Compose.

```sh
docker compose up --build
```

Open http://localhost:3000. On the first start the database is created, migrated and seeded with 10,000 employees automatically.

Run the test suite in Docker, against its own test database:

```sh
docker compose run --rm test
```

The `SECRET_KEY_BASE` in `docker-compose.yml` is for local use only.

## Run locally

Requires Ruby 3.4.11, Node 24 (see `frontend/.nvmrc`) and PostgreSQL 16.

```sh
bin/setup --skip-server       # gems, databases, seed
npm --prefix frontend ci      # frontend packages
bin/dev                       # Rails on :3000, Vite on :5173
```

Open http://localhost:5173. Vite proxies `/api` to Rails.

## Demo login

`hr@example.com` / `password`

To use different credentials, set `HR_EMAIL` and `HR_PASSWORD` before seeding.

## Importing employees

On the Import page, download the template, fill in one employee per row and upload it (`.xlsx`, up to 5 MB).

| Column | Notes |
|---|---|
| `employee_code` | Unique. An existing code with identical details is skipped, so re-uploading is safe. |
| `full_name`, `department`, `job_title`, `bank_account_number` | Required. Spaces around values are trimmed. |
| `country` | Code or name, e.g. `IN` or `India` |
| `joined_on` | A date cell or `YYYY-MM-DD` |
| `annual_base`, `annual_allowances`, `annual_deductions` | Annual USD amounts, from 0 to 1,000,000,000 |

Each new employee gets a first salary revision on `joined_on`.

## Tests and checks

```sh
bundle exec rspec                 # backend tests (229 examples)
npm --prefix frontend test        # frontend tests with Vitest (31 tests)
bin/rubocop                       # Ruby style
npm --prefix frontend run lint    # frontend lint (oxlint)
bin/ci                            # RuboCop, bundler-audit, Brakeman and RSpec in one go
```

GitHub Actions runs on every pull request and push to `main`, with three jobs:
- **Backend:** RuboCop, Brakeman, bundler-audit, a schema check and RSpec.
- **Frontend:** oxlint, Vitest and the build.
- **Docker:** builds the image.

Features were built test-first. In the commit history, each `test:` commit with failing specs is followed by the `feat:` or `fix:` commit that makes them pass.

## Documentation

- [Requirements](docs/requirements.md): goal, scope, rules and formulas, what's left out and why, and known limitations
- [Architecture](docs/architecture.md): system, data model, services, API, pages, main flows and key decisions
- [Performance](docs/performance.md): measured timings for the seed, dashboard, import and payroll
- [AI prompts log](docs/ai-prompts.md): how AI was used at each step, and what I changed or rejected

**Stack:** Ruby 3.4.11, Rails 8.1, PostgreSQL 16, React 19 with Vite, Ant Design and `@ant-design/charts`, Node 24, RSpec and Vitest.
