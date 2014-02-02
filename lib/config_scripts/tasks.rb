require 'rails'
module ConfigScripts
  class RakeTasksRailtie < Rails::Railtie
    railtie_name :config_sripts_rake_tasks

    rake_tasks do
      load 'config_scripts/tasks/pending_migrations.rake'
      load 'config_scripts/tasks/seeds.rake'
    end
  end
end