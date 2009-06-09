class CreateContigs < ActiveRecord::Migration
  def self.up
    create_table :contigs do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :contigs
  end
end
