namespace :config_scripts do
  desc "Run pending config scripts"
  task :run_pending => :environment do
    ConfigScripts::Scripts::Script.run_pending_scripts
  end

  desc "List pending config scripts"
  task :list_pending => :environment do
    ConfigScripts::Scripts::Script.list_pending_scripts
  end

  desc "Rollback config script"
  task :rollback => :environment do
    ConfigScripts::Scripts::Script.rollback_script(ENV['SCRIPT'])
  end

  desc "Rollback config script"
  task :run => :environment do
    ConfigScripts::Scripts::Script.run(ENV['SCRIPT'])
  end
end