require "rails_helper"

RSpec.describe "API employee imports", type: :request do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let!(:india) { create(:country, code: "IN", name: "India") }

  def json
    response.parsed_body
  end

  def upload(file, filename: "employees.xlsx")
    Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: filename)
  end

  it "requires login for uploading and for the template" do
    post "/api/employee_imports", params: { file: upload(xlsx_file([ import_row ])) }
    expect(response).to have_http_status(:unauthorized)

    get "/api/employee_imports/template"
    expect(response).to have_http_status(:unauthorized)
  end

  context "when logged in" do
    before { sign_in(create(:user)) }

    it "imports the file and returns counts with the skipped and failed rows" do
      post "/api/employee_imports", params: { file: upload(xlsx_file([ import_row, import_row(employee_code: "EMP90002", country: "Atlantis") ])) }

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "created" => 1, "skipped" => 0, "failed" => 1,
        "rows" => [ { "row" => 3, "employee_code" => "EMP90002", "status" => "failed", "reasons" => [ "country 'Atlantis' not found" ] } ]
      )
    end

    it "returns 422 when no file is sent" do
      post "/api/employee_imports", params: {}

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => { "code" => "invalid_file", "message" => "Choose an .xlsx file to upload." })
    end

    it "returns 422 for a file without the .xlsx extension, before reading it" do
      expect(Roo::Excelx).not_to receive(:new)

      post "/api/employee_imports", params: { file: upload(xlsx_file([ import_row ]), filename: "employees.csv") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to eq("Only .xlsx files are accepted.")
    end

    it "returns 422 for a renamed file that isn't really .xlsx" do
      csv = Tempfile.new([ "fake", ".xlsx" ]).tap { |f| f.write("employee_code,full_name\nEMP1,A\n"); f.rewind }

      post "/api/employee_imports", params: { file: upload(csv) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to eq("Only .xlsx files are accepted.")
    end

    it "returns 422 for a file over 5 MB, before reading it" do
      expect(Roo::Excelx).not_to receive(:new)
      big = Tempfile.new([ "big", ".xlsx" ]).tap { |f| f.binmode; f.write("PK\x03\x04" + ("x" * (5 * 1024 * 1024))); f.rewind }

      post "/api/employee_imports", params: { file: upload(big) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to eq("The file is larger than 5 MB.")
    end

    it "returns 422 with the reason when the file itself is unusable" do
      post "/api/employee_imports", params: { file: upload(xlsx_file([ [ "EMP1" ] ], headers: %w[employee_code])) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("invalid_file")
      expect(json.dig("error", "message")).to start_with("The file is missing columns: full_name")
    end

    it "downloads an empty template with the expected headers" do
      get "/api/employee_imports/template"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      expect(response.headers["Content-Disposition"]).to include('filename="employee_import_template.xlsx"')

      file = Tempfile.new([ "template", ".xlsx" ]).tap { |f| f.binmode; f.write(response.body); f.rewind }
      sheet = Roo::Excelx.new(file.path).sheet(0)
      expect(sheet.row(1)).to eq(Employees::Importer::COLUMNS)
      expect(sheet.last_row).to eq(1)
    end
  end
end
