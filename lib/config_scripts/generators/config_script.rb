require 'rails/generators'
module ConfigScripts
  # This class provides a generator for creating a config new script.
  class ConfigScriptGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../../../../templates', __FILE__)

    # This method creates a new config script.
    #
    # It will take a template file from +templates/config_scripts+, and the
    # name passed in when runing the generator, and create a file under
    # +db/config_scripts+ in the app.
    #
    # The config script filename will be prefixed with a timestamp, like a
    # database migration. The class defined in the config script will have
    # the name passed in to the generator.
    #
    # @return [Nil]
    def config_script
      path = "db/config_scripts/#{Time.now.to_s(:number)}_#{self.file_name}.rb"
      template "config_script.rb", path, {name: name}
      nil
    end
  end
end
