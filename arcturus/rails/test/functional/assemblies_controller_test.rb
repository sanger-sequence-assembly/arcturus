require 'test_helper'

class AssembliesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:assemblies)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create assembly" do
    assert_difference('Assembly.count') do
      post :create, :assembly => { }
    end

    assert_redirected_to assembly_path(assigns(:assembly))
  end

  test "should show assembly" do
    get :show, :id => assemblies(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => assemblies(:one).to_param
    assert_response :success
  end

  test "should update assembly" do
    put :update, :id => assemblies(:one).to_param, :assembly => { }
    assert_redirected_to assembly_path(assigns(:assembly))
  end

  test "should destroy assembly" do
    assert_difference('Assembly.count', -1) do
      delete :destroy, :id => assemblies(:one).to_param
    end

    assert_redirected_to assemblies_path
  end
end
