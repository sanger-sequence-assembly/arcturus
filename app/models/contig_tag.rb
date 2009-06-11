class ContigTag < ActiveRecord::Base
  has_many :tag_to_contigs, :foreign_key => "tag_id"
  has_many :contigs, :through => :tag_to_contigs

  set_table_name 'CONTIGTAG'
  self.primary_key = "tag_id"
end
