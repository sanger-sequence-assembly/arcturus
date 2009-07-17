class DiagnosticsController < ApplicationController
  def index
    @primary_object_types = [ Assembly, Contig, Project, ContigTag, TagMapping ]
    @connection_pools = Set.new

    @primary_object_types.each do |pot|
      @connection_pools.merge pot.connection_handler.connection_pools.values.to_set
    end

    @my_host = request.host
    @my_port = request.port
    @my_host_with_port = request.host_with_port

    @my_class= self.class

    respond_to do |format|
      format.html # index.html.erb
    end
  end
end
