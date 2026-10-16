class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :code, null: false, limit: 2
      t.string :name, null: false
      t.decimal :tax_rate, null: false, precision: 5, scale: 4

      t.timestamps
    end
    add_index :countries, :code, unique: true
    add_index :countries, :name, unique: true
    add_check_constraint :countries, "tax_rate BETWEEN 0 AND 1", name: "countries_tax_rate_range"
  end
end
