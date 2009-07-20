# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  before_filter :login_required
  before_filter :get_database_connection

private

  def get_database_connection
    dbparams = DatabaseConnectionManager.get_database_parameters(params['instance'], params['organism'])

    ActiveRecord::Base.establish_connection(dbparams)
  end

  def login_required
    login_from_session || login_from_cookie || login_from_api_key || authenticate_user
  end

  def login_from_session
    logger.debug "Invoked ApplicationController.login_from_session"
    logger.debug "session[user] is " + (session[:user].nil? ? "undefined" : session[:user])
    !session[:user].nil?
  end

  def login_from_cookie
    logger.debug "Invoked ApplicationController.login_from_cookie"

    return false unless cookies[:auth_key]

    logger.debug "cookies[auth_key] is " + cookies[:auth_key]

    sess = Session.find_by_auth_key(cookies[:auth_key])

    if sess.nil?
      logger.debug "Failed to find a match to the cookie"
      false
    else
      logger.debug "Found session : " + sess.inspect
      session[:user] = sess.username
      true
    end
  end

  def login_from_api_key
    logger.debug "Invoked ApplicationController.login_from_api_key"

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

  def authenticate_user
    session[:return_to] = request.request_uri
    redirect_to :controller => 'sessions', :action => 'login'
  end
end
