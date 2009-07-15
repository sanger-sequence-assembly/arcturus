require 'test_helper'

class ContigTagsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:contig_tags)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create contig_tag" do
    assert_difference('ContigTag.count') do
      post :create, :contig_tag => { }
    end

    assert_redirected_to contig_tag_path(assigns(:contig_tag))
  end

  test "should show contig_tag" do
    get :show, :id => contig_tags(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => contig_tags(:one).to_param
    assert_response :success
  end

  test "should update contig_tag" do
    put :update, :id => contig_tags(:one).to_param, :contig_tag => { }
    assert_redirected_to contig_tag_path(assigns(:contig_tag))
  end

  test "should destroy contig_tag" do
    assert_difference('ContigTag.count', -1) do
      delete :destroy, :id => contig_tags(:one).to_param
    end

    assert_redirected_to contig_tags_path
  end
end
