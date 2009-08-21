class SessionsController < ApplicationController
  skip_before_filter :login_required, :only => :login
  skip_before_filter :get_database_connection, :only => [:login, :logout]

  def login
    return unless request.post?
    if AuthenticationManager.authenticate(params[:username], params[:password])
      initialise_session(params[:username])
 
      if session[:return_to].nil?
        redirect_to :controller => 'arcturus', :action => 'index', :instance => 'test'
      else
        new_url = session[:return_to]
        session.delete :return_to
        redirect_to new_url
      end
    else
      redirect_to :controller => 'sessions', :action => 'access_denied'
    end
  end

  def logout
    delete_authentication_cookie
    reset_session
  end

  def access_denied
    respond_to do |format|
      format.html
    end
  end

  def profile
    username = find_user_from_session || find_user_from_cookie || find_user_from_api_key

    @my_session = username.nil? ? nil : Session.find_by_username(username)

    if @my_session
      user = params['organism'] ? User.find_by_username(username) : nil
      @role = user.nil? ? nil : user.role

      @title = params['organism'] ? "My profile for " + params['organism'] : "My profile"

      respond_to do |format|
        format.html
      end
    else
      force_user_login
    end
  end

private

  def initialise_session(username)
    sess = Session.find_or_create_by_username(username)

    if sess.auth_key.nil?
      sess.auth_key = Digest::SHA1.hexdigest(Time.now.to_s + sess.username)[1..32]
      sess.auth_key_expires = 2.days.from_now
    end

    if sess.api_key.nil?
      sess.api_key = Digest::SHA1.hexdigest(Time.now.to_s + sess.object_id.to_s)[1..32]
      sess.api_key_expires = 2.years.from_now
    end

    sess.save
    set_authentication_cookie({ :value => sess.auth_key, :expires => sess.auth_key_expires })
    session[:user] = username
  end
end
