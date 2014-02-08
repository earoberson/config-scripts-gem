require 'rails/generators'
module ConfigScripts
  # This class provides a generator for creating the migrations that we need to
  # use this gem.
  class MigrationsGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path('../../../../templates', __FILE__)

    # This generator creates the migrations that we need for the gem.
    def create_migrations
      copy_migration 'create_config_scripts'
    end

    # This method gets the number for the next migration created by this
    # generator.
    #
    # @param [String] dirname
    #   The name of the directory in which we are creating the migrations.
    #
    # We use the current timestamp.
    def self.next_migration_number(dirname)
      Time.now.to_s(:number)
    end

    protected

    # This method copies a migration from our template directory to the app's
    # migrations directory.
    #
    # @param [String] filename
    #   The name of the file in the templates directory.
    def copy_migration(filename)
      migration_template "#{filename}_migration.rb", "db/migrate/#{filename}.rb"
    end
  end
end