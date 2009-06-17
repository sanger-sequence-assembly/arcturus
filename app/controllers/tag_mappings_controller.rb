class TagMappingsController < ApplicationController
  # Bypass authentication for the moment
  skip_before_filter :verify_authenticity_token

  # GET /tag_mappings
  # GET /tag_mappings.xml
  def index
    @tag_mappings = TagMapping.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tag_mappings }
    end
  end

  # GET /tag_mappings/1
  # GET /tag_mappings/1.xml
  def show
    @tag_mapping = TagMapping.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag_mapping }
    end
  end

  # GET /tag_mappings/new
  # GET /tag_mappings/new.xml
  def new
    @tag_mapping = TagMapping.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag_mapping }
    end
  end

  # GET /tag_mappings/1/edit
  def edit
    @tag_mapping = TagMapping.find(params[:id])
  end

  # POST /tag_mappings
  # POST /tag_mappings.xml
  def create
    @contig_tag = ContigTag.find_or_create_by_systematic_id_and_tagtype(params[:contig_tag])

    @tag_mapping = TagMapping.new(params[:tag_mapping])
    @tag_mapping.tag = @contig_tag
    @tag_mapping.contig_id = params['contig_id']

    respond_to do |format|
      if (@tag_mapping.save!)
        flash[:notice] = 'TagMapping was successfully created.'
        format.html { redirect_to({:controller => "contigs",:action => "list_tags", :instance => params[:instance], :organism => params[:organism], :id => @tag_mapping.contig_id}) }
        format.xml  { head :ok }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag_mapping.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tag_mappings/1
  # PUT /tag_mappings/1.xml
  def update
    @tag_mapping = TagMapping.find(params[:id])

    respond_to do |format|
      if @tag_mapping.update_attributes(params[:tag_mapping])
        flash[:notice] = 'TagMapping was successfully updated.'
        format.html { redirect_to(@tag_mapping) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag_mapping.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tag_mappings/1
  # DELETE /tag_mappings/1.xml
  def destroy
    @tag_mapping = TagMapping.find(params[:id])
    @tag_mapping.destroy

    respond_to do |format|
      format.html { redirect_to(tag_mappings_url) }
      format.xml  { head :ok }
    end
  end


  # FIND TAG /tag_mappings/find_contig_tag/1
  def find_contig_tag
    @tag = ContigTag.find_by_systematic_id(params[:id])

    respond_to do |format|
      if ! @tag.nil?
        @query = "select T2C.* from TAG2CONTIG T2C,CURRENTCONTIGS CC where tag_id = #{@tag.tag_id} and T2C.contig_id = CC.contig_id"
        @mappings = TagMapping.find_by_sql(@query)
        format.html
        format.xml { render :xml => @mappings.to_xml(:include => :tag) }
      else
        format.html { redirect_to :status => 404 }
        format.xml  { head :ok }
      end
    end
  end

end
