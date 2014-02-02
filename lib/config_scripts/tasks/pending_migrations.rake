namespace :config_scripts do
  desc "Run pending config scripts"
  task :run_pending => :environment do
    ConfigScripts::Scripts::Script.run_pending_scripts
  end
end