class CreateTagToContigs < ActiveRecord::Migration
  def self.up
    create_table :tag_to_contigs do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :tag_to_contigs
  end
end
