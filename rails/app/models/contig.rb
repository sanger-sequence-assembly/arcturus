require 'zlib'

class Contig < ActiveRecord::Base
  set_table_name 'CONTIG'
  self.primary_key = "contig_id"

  belongs_to :project

  validates_presence_of :project
  validates_numericality_of :length
  validates_numericality_of :nreads

  has_many :tag_mappings
  has_many :tags, :through => :tag_mappings

  @@inflater = Zlib::Inflate.new
 
  def get_consensus(depad=false)
    query = "select sequence from CONSENSUS where contig_id = #{contig_id}"
    cseq = connection.select_all(query).first
    if ! cseq.nil?
      @@inflater.reset
      seq = @@inflater.inflate(cseq['sequence'])
      @@inflater.finish
      if (depad)
        seq.gsub!("-", "")
      end
      seq
    else
      nil
    end
  end

  def to_fasta(verbose=false)
    seq = get_consensus
    seqlen = seq.length
    fasta = String.new
    fasta.concat(">contig#{contig_id}")

    if verbose
      cstr = created.strftime("%Y-%m-%d_%H:%M:%S")
      fasta.concat(" length=#{length} reads=#{nreads} created=#{cstr} project=#{project.name}")
    end

    fasta.concat("\n")
    0.step(seq.length, 50) do |offset|
      fasta.concat(seq.slice(offset, 50))
      fasta.concat("\n");
    end
    fasta
  end

  def parents
    Contig.find_by_sql("select * from CONTIG where contig_id in (select parent_id from C2CMAPPING where contig_id = #{contig_id}) order by contig_id desc")
  end
end
