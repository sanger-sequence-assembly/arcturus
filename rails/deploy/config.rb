set :application, "Arcturus on Rails"

set :use_sudo, false
set :checkout, :export
set :keep_releases, 25
set :deploy_via, :export

set :user, 'arcturus'
set :group, 'psg'
set :password, proc { Capistrano::CLI.password_prompt('Password for arcturus:') }

role :app, "psd-dev.internal.sanger.ac.uk"

role :frontend, "psd-dev.internal.sanger.ac.uk"

set :repository_base, "svn+ssh://svn.internal.sanger.ac.uk/repos/svn/arcturus"

set :repository, "#{repository_base}/branches/adh/rails"

set :deploy_base, "/software/arcturus/webapp"
set :deploy_name, "arcturus"
set :environment, "training"
set :deploy_to, "#{deploy_base}/#{environment}"

set :reverse_proxy, "/software/webapp/nginx/bin/fairnginx"

desc "Symlink shared configuration files"
task :after_update_code, @roles => :app do
  files = ["config/database.yml",
           "config/ldap/authentication_manager.yml",
           "config/ldap/database_connection_manager.yml",
           "config/ldap/user.yml",
           "config/models/session.yml"]

  files.each do |filename|
    run "cd #{release_path} ; ln -nsf #{shared_path}/#{filename} #{release_path}/#{filename}"
  end

  run "cd #{release_path}/config ; ln -nsf environment.default.rb environment.rb"
end

namespace :deploy do
  task :start, :roles => :app do
    run "mongrel_rails cluster::start -C #{shared_path}/config/mongrel_cluster.yml"
  end

  task :restart, :roles => :app do
    run "mongrel_rails cluster::restart -C #{shared_path}/config/mongrel_cluster.yml"
  end

  task :stop, :roles => :app do
    run "mongrel_rails cluster::stop -C #{shared_path}/config/mongrel_cluster.yml"
  end

  task :start_nginx, :roles => :frontend do
    run "#{reverse_proxy} -c #{shared_path}/config/nginx.conf"
  end

  task :stop_nginx, :roles => :frontend do
    fp = File.open("#{shared_path}/log/nginx.pid", "r")
    pid = fp.readline
    pid.chomp!
    fp.close

    run "kill -TERM #{pid}"
  end

  task :migrate do
    puts "*** There are no migrations in Arcturus"
  end

  task :migrations do
    puts "*** There are no migrations in Arcturus"
  end
end
