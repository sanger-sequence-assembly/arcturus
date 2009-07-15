require 'test_helper'

class ContigsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:contigs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create contig" do
    assert_difference('Contig.count') do
      post :create, :contig => { }
    end

    assert_redirected_to contig_path(assigns(:contig))
  end

  test "should show contig" do
    get :show, :id => contigs(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => contigs(:one).to_param
    assert_response :success
  end

  test "should update contig" do
    put :update, :id => contigs(:one).to_param, :contig => { }
    assert_redirected_to contig_path(assigns(:contig))
  end

  test "should destroy contig" do
    assert_difference('Contig.count', -1) do
      delete :destroy, :id => contigs(:one).to_param
    end

    assert_redirected_to contigs_path
  end
end
