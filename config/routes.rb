ActionController::Routing::Routes.draw do |map|
  map.connect "login", :controller => 'sessions', :action => 'login'
  map.connect "logout", :controller => 'sessions', :action => 'logout'
  map.connect "access_denied", :controller => 'sessions', :action => 'access_denied'

  map.connect "/:instance/:organism/profile", :controller => 'sessions', :action => 'profile'

  map.resources :assemblies,
                  :path_prefix => "/:instance/:organism",
                  :member => { :projects => :get
                             }

  map.resources :projects,
                  :path_prefix => "/:instance/:organism",
                  :member => { :contigs => :get,
                               :export => :get
                             }

  map.connect "/:instance/:organism/contigs/export", :controller => 'contigs', :action => 'export'
  map.connect "/:instance/:organism/contigs/export.:format", :controller => 'contigs', :action => 'export'

  map.connect "/:instance/:organism/contigs/current", :controller => 'contigs', :action => 'current'
  map.connect "/:instance/:organism/contigs/current.:format", :controller => 'contigs', :action => 'current'

  map.resources :contigs,
                  :path_prefix => "/:instance/:organism",
                  :member => { :tags => :get,
                               :add_tag => :get,
                               :sequence => :get,
                               :parents => :get,
                               :export => :get
                             }

  map.resources :contig_tags,
                  :path_prefix => "/:instance/:organism"

  map.connect "/:instance/:organism/contig_tags/search/:pattern", :controller => 'contig_tags',
    :action => 'search'

  map.resources :tag_mappings, :path_prefix => "/:instance/:organism"

  map.resources :users, :path_prefix => "/:instance/:organism"

  map.connect ":instance/:organism/diagnostics", :controller => 'diagnostics', :action => 'index'

  map.connect "arcturus/:instance/:subclass", :controller => 'arcturus', :action => 'index'
  map.connect "arcturus/:instance", :controller => 'arcturus', :action => 'index'
end
