class CreateTagMappings < ActiveRecord::Migration
  def self.up
    create_table :tag_mappings do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :tag_mappings
  end
end
