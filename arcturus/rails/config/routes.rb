ActionController::Routing::Routes.draw do |map|
  map.resources :assemblies,
                  :path_prefix => "/:instance/:organism"

  map.resources :projects,
                  :path_prefix => "/:instance/:organism",
                  :member => { :contigs => :get, :export => :get, :delete_confirm => :get }

  map.resources :contigs,
                  :path_prefix => "/:instance/:organism",
                  :member => { :tags => :get, :add_tag => :get, :sequence => :get }

  map.resources :contig_tags, :path_prefix => "/:instance/:organism"

  map.resources :tag_mappings, :path_prefix => "/:instance/:organism"

  #map.connect ":instance/:organism/:controller"
  #map.connect ":instance/:organism/:controller/:action"
  #map.connect ":instance/:organism/:controller/:action/:id"
  #map.connect ":instance/:organism/:controller/:action/:id.:format"

  map.connect "arcturus/:instance", :controller => 'arcturus', :action => 'index'
end
