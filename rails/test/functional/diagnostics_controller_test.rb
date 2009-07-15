require 'test_helper'

class DiagnosticsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:diagnostics)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create diagnostic" do
    assert_difference('Diagnostic.count') do
      post :create, :diagnostic => { }
    end

    assert_redirected_to diagnostic_path(assigns(:diagnostic))
  end

  test "should show diagnostic" do
    get :show, :id => diagnostics(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => diagnostics(:one).to_param
    assert_response :success
  end

  test "should update diagnostic" do
    put :update, :id => diagnostics(:one).to_param, :diagnostic => { }
    assert_redirected_to diagnostic_path(assigns(:diagnostic))
  end

  test "should destroy diagnostic" do
    assert_difference('Diagnostic.count', -1) do
      delete :destroy, :id => diagnostics(:one).to_param
    end

    assert_redirected_to diagnostics_path
  end
end
