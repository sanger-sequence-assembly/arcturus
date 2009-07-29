require 'test_helper'

class TagMappingsControllerTest < ActionController::TestCase
  fixtures :sessions, :CONTIG, :CONTIGTAG, :TAG2CONTIG

  def setup
    @fred = sessions(:fred)
    @api_key = @fred.api_key
    @mapping = TAG2CONTIG(:default_mapping)
  end

  test "should create tag mapping" do
    contig = Contig.find(1)
    assert_not_nil(contig)

    assert_difference('TagMapping.count') do
      post :create, :instance => 'testing',
                    :organism => 'TESTDB_ADH',
                    :api_key => @api_key,
		    :contig_id => contig.contig_id,
		    :tag_mapping => {:cstart => 1,
		                     :cfinal => 100,
		                     :strand => 'F'},
		    :contig_tag => {:tagtype => 'FTST',
		                    :systematic_id => 'FTST_000001'}
    end
  end

  test "should update tag mapping" do
    put :update, :instance => 'testing',
                 :organism => 'TESTDB_ADH',
                 :api_key => @api_key,
                 :id => @mapping.id,
                 :tag_mapping => {:id => @mapping.id,
                                  :cstart => 1,
                                  :cfinal => 150,
                                  :strand => 'F',
                                  :contig_id => @mapping.contig_id}
  end

  test "should delete tag mapping" do
    @sacrificial_mapping = TAG2CONTIG(:sacrificial_mapping)

    assert_difference('TagMapping.count', -1) do
      delete :destroy, :instance => 'testing',
                       :organism => 'TESTDB_ADH',
                       :api_key => @api_key,
                       :id => @sacrificial_mapping.id
    end
  end

end
