module Employees
  class Importer
    class InvalidFile < StandardError; end

    COLUMNS = %w[employee_code full_name country department job_title bank_account_number joined_on
                 annual_base annual_allowances annual_deductions].freeze
    EMPLOYEE_FIELDS = %w[employee_code full_name department job_title bank_account_number joined_on].freeze
    AMOUNT_FIELDS = %w[annual_base annual_allowances annual_deductions].freeze
    BATCH_SIZE = 1_000

    def initialize(path)
      @path = path
    end

    def call
      sheet = open_sheet
      positions = column_positions(sheet)
      raise InvalidFile, "The file has no employee rows." if sheet.last_row.to_i < 2

      rows = (2..sheet.last_row).filter_map do |number|
        cells = sheet.row(number)
        [ number, positions.transform_values { |index| cells[index] } ] unless cells.all?(&:blank?)
      end
      raise InvalidFile, "The file has no employee rows." if rows.empty?

      process(rows)
    end

    private
      def open_sheet
        Roo::Excelx.new(@path).sheet(0)
      rescue Zip::Error, ArgumentError, Nokogiri::XML::SyntaxError, Roo::FileNotFound
        raise InvalidFile, "The file couldn't be read as .xlsx."
      end

      def column_positions(sheet)
        headers = Array(sheet.row(1)).map { |header| header.to_s.strip.downcase }
        missing = COLUMNS - headers
        raise InvalidFile, "The file is missing columns: #{missing.join(', ')}." if missing.any?

        COLUMNS.index_with { |column| headers.index(column) }
      end

      def process(rows)
        countries = country_lookup
        existing = existing_employees(rows.map { |_, cells| text(cells["employee_code"]) })
        seen_codes = Set.new
        results = []
        to_create = []

        rows.each do |number, cells|
          attributes, reasons = parse(cells, countries)
          code = attributes["employee_code"]

          if code.present? && seen_codes.include?(code)
            reasons = [ "duplicate employee code in this file" ]
          elsif code.present? && existing.key?(code)
            seen_codes << code
            if existing[code] == comparable(attributes)
              results << { row: number, employee_code: code, status: "skipped", reasons: [ "already exists" ] }
            else
              results << failed(number, code, [ "employee code already exists with different details" ])
            end
            next
          else
            seen_codes << code if code.present?
            reasons += model_errors(attributes, reasons)
          end

          if reasons.any?
            results << failed(number, code, reasons)
          else
            to_create << attributes
          end
        end

        insert(to_create)
        {
          created: to_create.size,
          skipped: results.count { |r| r[:status] == "skipped" },
          failed: results.count { |r| r[:status] == "failed" },
          rows: results.sort_by { |r| r[:row] }
        }
      end

      def parse(cells, countries)
        reasons = []
        attributes = EMPLOYEE_FIELDS.excluding("joined_on").index_with { |field| text(cells[field]) }

        country_name = text(cells["country"])
        if country_name.blank?
          reasons << "country can't be blank"
        else
          attributes["country_id"] = countries[country_name.downcase]
          reasons << "country '#{country_name}' not found" unless attributes["country_id"]
        end

        attributes["joined_on"] = date(cells["joined_on"])
        reasons << "joined_on must be a date (YYYY-MM-DD)" if attributes["joined_on"] == :invalid
        attributes["joined_on"] = nil if attributes["joined_on"] == :invalid

        AMOUNT_FIELDS.each do |field|
          attributes[field] = amount(cells[field])
          reasons << "#{field} must be a number" if attributes[field] == :invalid
          attributes[field] = nil if attributes[field] == :invalid
        end

        [ attributes, reasons ]
      end

      def model_errors(attributes, parse_reasons)
        already_reported = parse_reasons.map { |reason| reason.split.first }
        employee = Employee.new(attributes.slice(*EMPLOYEE_FIELDS).merge("country" => @countries_by_id[attributes["country_id"]]))
        revision = SalaryRevision.new(employee: employee, effective_on: attributes["joined_on"], reason: "initial",
          **attributes.slice(*AMOUNT_FIELDS))

        [ employee, revision ].flat_map do |record|
          validate_without_uniqueness(record)
          record.errors.filter_map do |error|
            next if error.attribute.in?(%i[country employee effective_on]) || error.attribute.to_s.in?(already_reported)

            "#{error.attribute} #{error.message}"
          end
        end.uniq
      end

      def validate_without_uniqueness(record)
        record.errors.clear
        record.class.validators.each do |validator|
          validator.validate(record) unless validator.is_a?(ActiveRecord::Validations::UniquenessValidator)
        end
      end

      def insert(rows)
        rows.each_slice(BATCH_SIZE) do |batch|
          ids = Employee.insert_all!(batch.map { |a| a.slice(*EMPLOYEE_FIELDS, "country_id") }, returning: %w[id employee_code])
            .rows.to_h { |id, code| [ code, id ] }
          SalaryRevision.insert_all!(batch.map do |a|
            { employee_id: ids.fetch(a["employee_code"]), effective_on: a["joined_on"], reason: "initial", **a.slice(*AMOUNT_FIELDS) }
          end)
        end
      end

      def existing_employees(codes)
        Employee.where(employee_code: codes.compact_blank).includes(:salary_revisions).to_h do |employee|
          initial = employee.salary_revisions.find { |r| r.reason == "initial" }
          [ employee.employee_code, comparable(employee.attributes.merge(
            AMOUNT_FIELDS.index_with { |field| initial&.public_send(field) }
          )) ]
        end
      end

      def comparable(attributes)
        values = attributes.slice(*EMPLOYEE_FIELDS, "country_id", *AMOUNT_FIELDS)
        values.transform_values { |value| value.is_a?(Numeric) ? BigDecimal(value.to_s) : value }
      end

      def country_lookup
        countries = Country.all.to_a
        @countries_by_id = countries.index_by(&:id)
        countries.each_with_object({}) do |country, lookup|
          lookup[country.code.downcase] = country.id
          lookup[country.name.downcase] = country.id
        end
      end

      def failed(number, code, reasons)
        { row: number, employee_code: code.presence, status: "failed", reasons: reasons }
      end

      def text(value)
        value = value.to_i if value.is_a?(Float) && value == value.floor
        value.to_s.strip
      end

      def date(value)
        return nil if value.blank?
        return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

        Date.iso8601(value.to_s.strip)
      rescue Date::Error
        :invalid
      end

      def amount(value)
        return nil if value.blank?
        return BigDecimal(value.to_s) if value.is_a?(Numeric)

        BigDecimal(value.to_s.strip)
      rescue ArgumentError
        :invalid
      end
  end
end
