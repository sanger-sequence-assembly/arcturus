require 'test_helper'

class TagToContigsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:tag_to_contigs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create tag_to_contig" do
    assert_difference('TagToContig.count') do
      post :create, :tag_to_contig => { }
    end

    assert_redirected_to tag_to_contig_path(assigns(:tag_to_contig))
  end

  test "should show tag_to_contig" do
    get :show, :id => tag_to_contigs(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => tag_to_contigs(:one).to_param
    assert_response :success
  end

  test "should update tag_to_contig" do
    put :update, :id => tag_to_contigs(:one).to_param, :tag_to_contig => { }
    assert_redirected_to tag_to_contig_path(assigns(:tag_to_contig))
  end

  test "should destroy tag_to_contig" do
    assert_difference('TagToContig.count', -1) do
      delete :destroy, :id => tag_to_contigs(:one).to_param
    end

    assert_redirected_to tag_to_contigs_path
  end
end
