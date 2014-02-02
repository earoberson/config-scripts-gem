require 'rails/generators'
module ConfigScripts
  class ConfigScriptGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../../../../templates', __FILE__)

    def config_script
      filename = name.underscore
      path = "db/config_scripts/#{Time.now.to_s(:number)}_#{filename}.rb"
      template "config_script.rb", path, {name: name}
    end
  end
end
