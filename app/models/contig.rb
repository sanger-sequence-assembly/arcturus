class Contig < ActiveRecord::Base
  belongs_to :project

  set_table_name 'CONTIG'
  self.primary_key = "contig_id"
end
