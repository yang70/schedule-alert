class CreatePersons < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :name, null: false
      t.string :color, null: false, default: '#3B82F6'
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :people, [:user_id, :name], unique: true
  end
end
