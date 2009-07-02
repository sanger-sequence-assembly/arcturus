class Contig < ActiveRecord::Base
  set_table_name 'CONTIG'
  set_primary_key "contig_id"

  belongs_to :project

  validates_presence_of :project
  validates_numericality_of :length
  validates_numericality_of :nreads

  has_many :tag_mappings
  has_many :tags, :through => :tag_mappings

  def get_consensus
    @query = "select sequence from CONSENSUS where contig_id = #{contig_id}"
    @cseq = connection.select_all(@query).first
    if ! @cseq.nil?
      INFLATER.reset
      @seq = INFLATER.inflate(@cseq['sequence'])
      INFLATER.finish
      @seq
    else
      nil
    end
  end

  def to_fasta
    @seq = get_consensus
    @seqlen = @seq.length
    @fasta = String.new
    @fasta.concat(">contig#{contig_id}\n")
    0.step(@seq.length, 50) do |offset|
      @fasta.concat(@seq.slice(offset, 50))
      @fasta.concat("\n");
    end
    @fasta
  end
end
