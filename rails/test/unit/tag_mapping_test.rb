require 'test_helper'

class TagMappingTest < ActiveSupport::TestCase
  fixtures :CONTIG, :CONTIGTAG, :TAG2CONTIG

  def setup
    @default_contig  = CONTIG(:default_contig)
    @default_tag     = CONTIGTAG(:default_tag)
    @test_tag_2      = CONTIGTAG(:test_tag_2)
    @test_tag_3      = CONTIGTAG(:test_tag_3)
    @default_mapping  = TAG2CONTIG(:default_mapping)
    @sacrificial_mapping = TAG2CONTIG(:sacrificial_mapping)
  end

  test "internal consistency" do
    assert_equal(@default_tag.id, @default_mapping.tag.id)
  end

  test "create tag mapping" do
    mapping = TagMapping.new
    mapping.contig = @default_contig
    mapping.tag    = @default_tag
    mapping.cstart = 1
    mapping.cfinal = 100
    mapping.strand = "F"

    assert mapping.save
  end
end
