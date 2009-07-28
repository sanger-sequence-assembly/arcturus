require 'test_helper'

class TagMappingsControllerTest < ActionController::TestCase
  fixtures :sessions, :CONTIG, :CONTIGTAG, :TAG2CONTIG

  test "should create tag_mapping" do
    fred = Session.find_by_username('fred')
    assert_not_nil(fred)
    api_key = fred.api_key

    contig = Contig.find(1)
    assert_not_nil(contig)

    assert_difference('TagMapping.count') do
      post :create, :instance => 'testing',
                    :organism => 'TESTDB_ADH',
                    :api_key => api_key,
		    :contig_id => contig.contig_id,
		    :tag_mapping => {:cstart => 1,
		                     :cfinal => 100,
		                     :strand => 'F'},
		    :contig_tag => {:tagtype => 'FTST',
		                    :systematic_id => 'FTST_000001'}
    end
  end

end
