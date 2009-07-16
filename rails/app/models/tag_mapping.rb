class TagMapping < ActiveRecord::Base
  set_table_name 'TAG2CONTIG'

  belongs_to :contig
  belongs_to :tag, :class_name => 'ContigTag', :foreign_key => "tag_id"

  has_one :parent, :class_name => 'TagMapping', :primary_key => "parent_id", :foreign_key => "id"

  validates_numericality_of :cstart, :only_integer => true
  validates_numericality_of :cfinal, :only_integer => true
  validates_inclusion_of :strand, :in => %w{ F R U }

protected

  def validate
    errors.add(:cstart, "must be at least 1") if cstart < 1
    errors.add(:cfinal, "must be greater than cstart") if cfinal < cstart
  end
end
