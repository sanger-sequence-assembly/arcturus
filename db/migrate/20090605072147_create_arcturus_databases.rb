class CreateArcturusDatabases < ActiveRecord::Migration
  def self.up
    create_table :arcturus_databases do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :arcturus_databases
  end
end
