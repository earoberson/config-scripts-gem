namespace :config_scripts do
  namespace :seeds do
    desc "Dump seed data from the database"
    task :dump => :environment do
      ConfigScripts::Seeds::SeedSet.write(ENV['SET'].try(:to_i))
    end

    desc "Load seed data from the seed files"
    task :load => :environment do
      ConfigScripts::Seeds::SeedSet.read(ENV['SET'].try(:to_i))
    end

    desc "List all of the seed sets that the app has defined"
    task :list => [:environment] do
      ConfigScripts::Seeds::SeedSet.list
    end
  end
end