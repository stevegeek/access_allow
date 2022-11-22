# frozen_string_literal: true

class AddPermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :permissions do |t|
      t.string :ability_name
      t.references :user, foreign_key: true
      t.timestamps
    end
  end
end
