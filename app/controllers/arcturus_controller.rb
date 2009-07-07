class ArcturusController < ApplicationController
  skip_before_filter :get_database_connection

  # GET /arcturus
  def index
    @arcturus_instance = ArcturusInstance.new(params[:instance])

    @instance_name = params[:instance]

    @organisms = @arcturus_instance.organisms

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @arcturus_instance }
    end
  end
end
