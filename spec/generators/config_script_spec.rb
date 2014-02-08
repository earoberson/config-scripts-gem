require 'generator_spec'

describe ConfigScripts::ConfigScriptGenerator, type: :generator do
  destination File.expand_path("../../../tmp", __FILE__)
  arguments ['TestConfigScript']
  
  describe "config_script" do
    let(:expected_path) { "db/config_scripts/#{Time.now.to_s(:number)}_test_config_script.rb" }
    before do
      prepare_destination
      Timecop.freeze
      run_generator
    end

    after do
      Timecop.return
    end

    it "creates a file in the config_scripts directory, with a config script class" do
      assert_file expected_path, /class TestConfigScriptConfig < ConfigScripts::Scripts::Script/
    end
  end
end