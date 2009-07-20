class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery

  # Scrub sensitive parameters from your log
  filter_parameter_logging :password

  before_filter :login_required
  before_filter :get_database_connection

private

  def get_database_connection
    dbparams = DatabaseConnectionManager.get_database_parameters(params['instance'], params['organism'])

    ActiveRecord::Base.establish_connection(dbparams)
  end

  def login_required
    find_user_from_session || find_user_from_cookie || find_user_from_api_key || force_user_login
  end

  def find_user_from_session
    logger.debug "Invoked ApplicationController.find_user_from_session"
    logger.debug "session[user] is " + (session[:user].nil? ? "undefined" : session[:user])
    !session[:user].nil?
  end

  def find_user_from_cookie
    logger.debug "Invoked ApplicationController.find_user_from_cookie"

    auth_cookie = get_authentication_cookie

    return false unless auth_cookie

    logger.debug "cookies[" + get_cookie_name + "] is " + auth_cookie

    sess = Session.find_by_auth_key(auth_cookie)

    if sess.nil?
      logger.debug "Failed to find a match to the cookie"
      false
    else
      logger.debug "Found session : " + sess.inspect
      session[:user] = sess.username
      true
    end
  end

  def get_cookie_name
    ARCTURUS_COOKIE_NAME + "_" + request.port.to_s
  end

  def get_authentication_cookie
    cookie_name = get_cookie_name
    cookies[cookie_name]
  end

  def set_authentication_cookie(value)
    cookie_name = get_cookie_name
    cookies[cookie_name] = value
  end

  def delete_authentication_cookie
    cookie_name = get_cookie_name
    cookies.delete cookie_name
  end

  def find_user_from_api_key
    logger.debug "Invoked ApplicationController.find_user_from_api_key"

    return false unless params[:api_key]

    logger.debug "params[api_key] is " + params[:api_key]

    sess = Session.find_by_api_key(params[:api_key])

    if sess.nil?
      logger.debug "Failed to find a match to the API key"
      false
    else
      logger.debug "Found session : " + sess.inspect
      session[:user] = sess.username
      true
    end
  end

  def force_user_login
    session[:return_to] = request.request_uri
    redirect_to :controller => 'sessions', :action => 'login'
  end
end
