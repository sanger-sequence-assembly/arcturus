class Contig < ActiveRecord::Base
  belongs_to :project

  validates_presence_of :project
  validates_numericality_of :length
  validates_numericality_of :nreads

  has_many :tag_mappings
  has_many :tags, :through => :tag_mappings

  set_table_name 'CONTIG'
  self.primary_key = "contig_id"
end
