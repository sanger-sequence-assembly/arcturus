class ArcturusController < ApplicationController
  skip_before_filter :login_required
  skip_before_filter :get_database_connection

  # GET /arcturus
  def index
    @arcturus_instance = ArcturusInstance.new(params[:instance], params[:subclass])

    @instance_name = params[:instance]
    @subclass_name = params[:subclass]

    @organisms = @arcturus_instance.organisms

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @arcturus_instance }
    end
  end
end
