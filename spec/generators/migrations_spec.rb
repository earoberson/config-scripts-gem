describe ConfigScripts::MigrationsGenerator, type: :generator do
  destination File.expand_path("../../../tmp", __FILE__)

  describe "create_migrations" do
    before do
      prepare_destination
      run_generator
    end

    it "creates a migration for adding the config scripts table" do
      assert_file "db/migrate/#{Time.now.to_s(:number)}_create_config_scripts.rb", /create_table :config_scripts/
    end

    context "when running repeatedly" do
      it "says that it has skipped it" do
        output = capture :stderr do
          run_generator
        end
        expect(output).to be =~ /Another migration is already named create_config_scripts/
      end
    end
  end
end