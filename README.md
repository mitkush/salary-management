# Salary Management

A web app for ACME's HR Manager to manage salaries for about 10,000 employees across several countries: salary revisions, monthly payroll, and insights into how the org pays people.

- [Requirements](docs/requirements.md): scope, rules and what's deliberately left out
- [Architecture](docs/architecture.md): system, data model, services, API and key decisions
- [AI prompts log](docs/ai-prompts.md): how AI was used and what I changed or rejected

**Stack:** Ruby 3.4.11, Rails 8.1, PostgreSQL 16, React 19 with Vite and Ant Design, Node 24, RSpec.

## Run with Docker

Requires Docker with Compose.

```sh
docker compose up --build
```

Open http://localhost:3000. On the first start the database is created, migrated and seeded automatically.

**Demo login:** `hr@example.com` / `password`. Change it with `HR_EMAIL` and `HR_PASSWORD` before seeding.

Run the test suite in Docker, against its own test database:

```sh
docker compose run --rm test
```

The `SECRET_KEY_BASE` in `docker-compose.yml` is for local use only.

## Local development

Requires Ruby 3.4.11, Node 24 (see `frontend/.nvmrc`) and PostgreSQL 16 running locally.

```sh
bin/setup --skip-server       # gems, databases
npm --prefix frontend ci      # frontend packages
bin/dev                       # Rails on :3000, Vite on :5173
```

Open http://localhost:5173. Vite proxies `/api` to Rails. Log in with the demo login above.

## Importing employees

On the Import page, download the template, fill one employee per row and upload it (`.xlsx`, up to 5 MB).

| Column | Notes |
|---|---|
| `employee_code` | Unique. An existing code with identical details is skipped, so re-uploading is safe. |
| `full_name`, `department`, `job_title`, `bank_account_number` | Required; spaces around values are trimmed |
| `country` | Code or name, e.g. `IN` or `India` |
| `joined_on` | A date cell or `YYYY-MM-DD` |
| `annual_base`, `annual_allowances`, `annual_deductions` | Annual USD amounts, 0 to 1,000,000,000 |

Each new employee gets a first salary revision on `joined_on`. Rows with problems are listed with their row number and reason, and the rest are imported.

## Tests and checks

```sh
bundle exec rspec                 # tests
bin/rubocop                       # Ruby style
npm --prefix frontend run lint    # frontend lint (oxlint)
npm --prefix frontend test        # frontend tests (Vitest)
bin/ci                            # RuboCop, bundler-audit, Brakeman and RSpec in one go
```

GitHub Actions runs the backend checks, the frontend lint, tests and build, and a Docker image build on every pull request and push to `main`.
