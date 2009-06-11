class ContigTag < ActiveRecord::Base
  set_table_name 'CONTIGTAG'
  self.primary_key = "tag_id"
end
