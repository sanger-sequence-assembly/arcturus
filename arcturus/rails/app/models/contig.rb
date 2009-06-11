class Contig < ActiveRecord::Base
  belongs_to :project

  has_many :tag_to_contigs, :foreign_key => "contig_id"
  has_many :contig_tags, :through => :tag_to_contigs

  set_table_name 'CONTIG'
  self.primary_key = "contig_id"
end
