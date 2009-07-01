class ArcturusController < ApplicationController

  # GET /arcturus
  def index
     render_index
  end

#  def index
#    @inventory = @arcturus_instance.inventory
#    @number = @inventory.length
#    @instance = @arcturus_instance.instance_name
#    @view = @arcturus_instance.selection_name
#    respond_to do |format|
#      format.html # index.html.erb
#      format.xml  { render :xml => @projects }
#    end
#  end

  def pathogen
     render_index
  end

  def test
    render_index
  end

  def bacteria
    render_index
  end

  def helminths
    render_index
  end

  def protozoa
    render_index
  end

  def vectors
    render_index
  end

  def phages
    render_index
  end

  def vertebrates
    render_index
  end

protected

  def render_index

    @inventory = @arcturus_instance.inventory

    @number = @inventory.length

    @instance = @arcturus_instance.instance_name

    @view = @arcturus_instance.selection_name

    @return_path = @view.split('-')
    @return_path.pop if @return_path 

    render(:action => 'index')
  end

end
