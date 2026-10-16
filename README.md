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

Open http://localhost:5173. Vite proxies `/api` to Rails.

## Tests and checks

```sh
bundle exec rspec                 # tests
bin/rubocop                       # Ruby style
npm --prefix frontend run lint    # frontend lint (oxlint)
bin/ci                            # RuboCop, bundler-audit, Brakeman and RSpec in one go
```

GitHub Actions runs the backend checks, the frontend lint and build, and a Docker image build on every pull request and push to `main`.
