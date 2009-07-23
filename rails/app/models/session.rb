class Session < ActiveRecord::Base
  unless RAILS_ENV == 'test'
    config = YAML::load(File.open("#{RAILS_ROOT}/config/models/session.yml"))[RAILS_ENV]
    Session.establish_connection(
      DatabaseConnectionManager.get_database_parameters(config['instance'], config['database'], false))

    set_table_name 'USER'
  end

  self.primary_key = "username"
end
