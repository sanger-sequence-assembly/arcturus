class ContigTag < ActiveRecord::Base
  has_many :tag_mappings, :foreign_key => "tag_id"

  set_table_name 'CONTIGTAG'
  self.primary_key = "tag_id"
end
