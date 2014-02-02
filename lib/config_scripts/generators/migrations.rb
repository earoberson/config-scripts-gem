require 'rails/generators'
module ConfigScripts
  class MigrationsGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path('../../../../templates', __FILE__)

    def create_migrations
      copy_migration 'create_config_scripts'
    end

    def self.next_migration_number(dirname)
      Time.now.to_s(:number)
    end

  protected
    def copy_migration(filename)
      if self.class.migration_exists?("db/migrate", "#{filename}")
        say_status("skipped", "Migration #{filename}.rb already exists")
      else
        migration_template "#{filename}.rb", "db/migrate/#{filename}.rb"
      end
    end
  end
end