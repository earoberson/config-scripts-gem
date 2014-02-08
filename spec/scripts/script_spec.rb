describe ConfigScripts::Scripts::Script do
  describe "class methods" do
    describe "script_directory" do
      it "is the db/config_scripts directory" do
        expect(ConfigScripts::Scripts::Script.script_directory).to eq Rails.root.join('db', 'config_scripts')
      end
    end

    pending "pending_scripts"
    pending "run_pending_scripts"
  end

  pending "creating"

  describe "running" do
    pending "up"
    pending "down"
    pending "run"
  end
end