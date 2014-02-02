namespace :config_scripts do
  namespace :seeds do
    desc "Dump seed data from the database"
    task :dump => :environment do
      ConfigScripts::Seeds::SeedSet.write
    end

    desc "Load seed data from the seed files"
    task :load => :environment do
      ConfigScripts::Seeds::SeedSet.read
    end
  end
end