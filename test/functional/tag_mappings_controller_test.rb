require 'test_helper'

class TagMappingsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:tag_mappings)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create tag_mapping" do
    assert_difference('TagMapping.count') do
      post :create, :tag_mapping => { }
    end

    assert_redirected_to tag_mapping_path(assigns(:tag_mapping))
  end

  test "should show tag_mapping" do
    get :show, :id => tag_mappings(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => tag_mappings(:one).to_param
    assert_response :success
  end

  test "should update tag_mapping" do
    put :update, :id => tag_mappings(:one).to_param, :tag_mapping => { }
    assert_redirected_to tag_mapping_path(assigns(:tag_mapping))
  end

  test "should destroy tag_mapping" do
    assert_difference('TagMapping.count', -1) do
      delete :destroy, :id => tag_mappings(:one).to_param
    end

    assert_redirected_to tag_mappings_path
  end
end
