class SessionsController < ApplicationController
  skip_before_filter :login_required
  skip_before_filter :get_database_connection

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
    cookies.delete :auth_key
    reset_session
  end

  def access_denied
    respond_to do |format|
      format.html
     end
  end

private

  def initialise_session(username)
     sess = Session.find_or_create_by_username(username)
     sess.auth_key = Digest::SHA1.hexdigest(Time.now.to_s + sess.username)[1..32]
     sess.auth_key_expires = 2.days.from_now
     sess.save
     cookies[:auth_key] = { :value => sess.auth_key, :expires => sess.auth_key_expires }
     session[:user] = username
  end
end
