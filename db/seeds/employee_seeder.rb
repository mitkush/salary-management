class EmployeeSeeder
  BATCH_SIZE = 1_000

  COUNTRIES = [
    { code: "US", name: "United States", tax_rate: "0.2500", pay_factor: 1.00, weight: 25 },
    { code: "IN", name: "India", tax_rate: "0.2000", pay_factor: 0.25, weight: 30 },
    { code: "GB", name: "United Kingdom", tax_rate: "0.2200", pay_factor: 0.80, weight: 15 },
    { code: "DE", name: "Germany", tax_rate: "0.3000", pay_factor: 0.85, weight: 10 },
    { code: "SG", name: "Singapore", tax_rate: "0.1200", pay_factor: 0.75, weight: 10 },
    { code: "BR", name: "Brazil", tax_rate: "0.2750", pay_factor: 0.30, weight: 10 }
  ].freeze

  JOB_TITLES = [
    { department: "Engineering", title: "Software Engineer", us_base: 95_000..140_000, weight: 22 },
    { department: "Engineering", title: "Senior Software Engineer", us_base: 140_000..190_000, weight: 12 },
    { department: "Engineering", title: "Engineering Manager", us_base: 170_000..230_000, weight: 4 },
    { department: "Engineering", title: "QA Engineer", us_base: 70_000..105_000, weight: 6 },
    { department: "Product", title: "Product Manager", us_base: 120_000..170_000, weight: 5 },
    { department: "Product", title: "Product Designer", us_base: 90_000..135_000, weight: 4 },
    { department: "Sales", title: "Account Executive", us_base: 65_000..110_000, weight: 10 },
    { department: "Sales", title: "Sales Manager", us_base: 110_000..160_000, weight: 3 },
    { department: "Marketing", title: "Marketing Specialist", us_base: 55_000..85_000, weight: 6 },
    { department: "Marketing", title: "Marketing Manager", us_base: 100_000..145_000, weight: 2 },
    { department: "Finance", title: "Accountant", us_base: 60_000..90_000, weight: 5 },
    { department: "Finance", title: "Financial Analyst", us_base: 75_000..110_000, weight: 5 },
    { department: "People", title: "HR Generalist", us_base: 55_000..85_000, weight: 6 },
    { department: "People", title: "Recruiter", us_base: 60_000..90_000, weight: 6 },
    { department: "People", title: "HR Manager", us_base: 95_000..135_000, weight: 4 }
  ].freeze

  FIRST_NAMES = %w[
    Aarav Aisha Alex Amara Ana Ananya Arjun Ben Carlos Chen Chloe Daniel Diya Elena Emma Ethan Fatima Felix
    Gabriel Hana Hannah Isabel Ishaan James Julia Kabir Kavya Leon Liam Lucas Maria Maya Mei Mohammed Noah
    Olivia Omar Priya Rahul Ravi Rohan Sara Sofia Tanvi Thomas Wei Yuki Zara
  ].freeze

  LAST_NAMES = %w[
    Adams Agarwal Almeida Becker Brown Chen Costa Das Fischer Garcia Gupta Hoffmann Iyer Johnson Kapoor Khan
    Kim Kumar Lee Lim Mehta Meyer Miller Nair Ng Oliveira Patel Pereira Rao Reddy Santos Schmidt Shah
    Silva Singh Smith Souza Tan Taylor Verma Wagner Walker Weber Williams Wilson Wong
  ].freeze

  def self.call(count: 10_000, random: Random.new(42), today: Date.current)
    new(count:, random:, today:).call
  end

  def self.base_range(country_code, job_title)
    pay_factor = COUNTRIES.find { |c| c[:code] == country_code }.fetch(:pay_factor)
    us_base = JOB_TITLES.find { |t| t[:title] == job_title }.fetch(:us_base)
    (us_base.min * pay_factor).round(-2)..(us_base.max * pay_factor).round(-2)
  end

  def initialize(count:, random:, today:)
    @count = count
    @random = random
    @today = today
  end

  def call
    country_ids = seed_countries
    return if Employee.exists?

    employees, revisions_by_code = build_rows(country_ids)

    employees.each_slice(BATCH_SIZE) do |batch|
      ids_by_code = Employee.insert_all!(batch, returning: %w[id employee_code]).rows.to_h { |id, code| [ code, id ] }
      revision_rows = ids_by_code.flat_map do |code, id|
        revisions_by_code.fetch(code).map { |revision| revision.merge(employee_id: id) }
      end
      SalaryRevision.insert_all!(revision_rows)
    end
  end

  private
    attr_reader :count, :random, :today

    def seed_countries
      COUNTRIES.to_h do |attributes|
        country = Country.find_or_create_by!(code: attributes[:code]) do |c|
          c.name = attributes[:name]
          c.tax_rate = attributes[:tax_rate]
        end
        [ attributes[:code], country.id ]
      end
    end

    def build_rows(country_ids)
      revisions_by_code = {}
      employees = (1..count).map do |number|
        code = format("EMP%05d", number)
        country = pick(COUNTRIES)
        job = pick(JOB_TITLES)
        joined_on, terminated_on = employment_dates
        revisions_by_code[code] = revisions_for(country, job, joined_on, terminated_on)

        {
          employee_code: code,
          full_name: "#{FIRST_NAMES.sample(random: random)} #{LAST_NAMES.sample(random: random)}",
          country_id: country_ids.fetch(country[:code]),
          department: job[:department],
          job_title: job[:title],
          bank_account_number: Array.new(12) { random.rand(10) }.join,
          joined_on: joined_on,
          terminated_on: terminated_on
        }
      end
      [ employees, revisions_by_code ]
    end

    def employment_dates
      roll = random.rand
      return [ today + random.rand(1..60), nil ] if roll < 0.02

      joined_on = today - random.rand(60..3_650)
      return [ joined_on, nil ] unless roll < 0.07

      [ joined_on, joined_on + random.rand(30..(today - joined_on - 1).to_i) ]
    end

    def revisions_for(country, job, joined_on, terminated_on)
      base = random.rand(self.class.base_range(country[:code], job[:title])).round(-2)
      revisions = [ revision(joined_on, base, "initial") ]

      last_day = terminated_on || today
      extra = random.rand < 0.4 ? random.rand(1..2) : 0
      extra.times do
        effective_on = revisions.last[:effective_on] + random.rand(365..540)
        break if effective_on > last_day

        promotion = random.rand < 0.25
        base = (base * (1 + (promotion ? random.rand(0.10..0.20) : random.rand(0.03..0.12)))).round(-2)
        revisions << revision(effective_on, base, promotion ? "promotion" : "increment")
      end
      revisions
    end

    def revision(effective_on, base, reason)
      {
        effective_on: effective_on,
        annual_base: base,
        annual_allowances: (base * random.rand(0.05..0.20)).round(2),
        annual_deductions: (base * random.rand(0.02..0.08)).round(2),
        reason: reason
      }
    end

    def pick(options)
      total = options.sum { |option| option[:weight] }
      target = random.rand(total)
      options.each do |option|
        target -= option[:weight]
        return option if target.negative?
      end
    end
end
