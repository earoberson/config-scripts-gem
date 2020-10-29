describe ConfigScripts::Scripts::Script do
  let(:klass) { ConfigScripts::Scripts::Script }

  describe "class methods" do
    describe "script_directory" do
      subject { klass.script_directory}
      it "is the db/config_scripts directory" do
        expect(subject).to eq Rails.root.join('db', 'config_scripts')
      end
    end

    describe "pending_scripts" do
      let!(:filename1) { "20140208150000_script_1" }
      let!(:filename2) { "20140208200000_script_2" }

      subject { klass.pending_scripts }

      before do
        Dir.stub glob: ["/tmp/#{filename1}.rb", "/tmp/#{filename2}.rb"]
        ConfigScripts::Scripts::ScriptHistory.record_timestamp('20140208150000')
      end

      it "uses Dir to get the files" do
        subject
        expect(Dir).to have_received(:glob).with(File.join(klass.script_directory, "*.rb"))
      end

      it "includes filenames that don't have entries in the script histories" do
        expect(subject).to include filename2
      end

      it "does not include filenames that have entries in the script history" do
        expect(subject).not_to include filename1
      end
    end

    describe "run_pending_scripts" do
      class TestConfigScriptConfig < ConfigScripts::Scripts::Script; end

      let!(:timestamp1) { '20140208150000' }
      let!(:timestamp2) { '20140208200000' }
      let!(:timestamp3) { '20140208250000' }

      let(:script_filenames) { [timestamp1, timestamp2, timestamp3].collect { |stamp| "#{stamp}_test_config_script" } }

      let!(:script1) { TestConfigScriptConfig.new(timestamp1) }
      let!(:script2) { TestConfigScriptConfig.new(timestamp2) }
      let!(:script3) { TestConfigScriptConfig.new(timestamp3) }

      before do
        klass.stub pending_scripts: script_filenames
        klass.stub :require
        klass.stub :puts
        [script1, script2, script3].each do |script|
          script.stub(:run)
        end

        TestConfigScriptConfig.stub(:new).with(timestamp1).and_return(script1)
        TestConfigScriptConfig.stub(:new).with(timestamp2).and_return(script2)
        TestConfigScriptConfig.stub(:new).with(timestamp3).and_return(script3)
      end

      let(:scripts) {[
        {
          filename: script_filenames[0],
          script: script1,
          run: true
        },
        {
          filename: script_filenames[1],
          script: script2,
          run: true
        },
        {
          filename: script_filenames[2],
          script: script3,
          run: true
        }
      ]}


      shared_examples "ran scripts" do
        it "requires only the scripts it needs to run" do
          scripts.each do |script|
            path = File.join(Rails.root.join("db", "config_scripts", "#{script[:filename]}.rb"))
            if script[:run]
              expect(klass).to have_received(:require).with(path)
            else
              expect(klass).not_to have_received(:require).with(path)
            end
          end
        end

        it "creates a config script for each timestamp with the appropriate class" do
          scripts.each do |script|
            timestamp = script[:filename].first(14)
            if script[:run]
              expect(TestConfigScriptConfig).to have_received(:new).with(timestamp)
            else
              expect(TestConfigScriptConfig).not_to have_received(:new).with(timestamp)
            end
          end
        end

        it "calls the up command on each script item" do
          scripts.each do |script|
            if script[:run]
              expect(script[:script]).to have_received(:run).with(:up)
            else
              expect(script[:script]).not_to have_received(:run)
            end
          end
        end

        it "outputs the name of the scripts that it is running" do
          scripts.each do |script|
            if script[:run]
              expect(klass).to have_received(:puts).with("Running #{script[:filename]}")
            else
              expect(klass).not_to have_received(:puts).with("Running #{script[:filename]}")
            end
          end
        end
      end

      context "with no problems running the scripts" do
        it_behaves_like "ran scripts"

        before do
          klass.run_pending_scripts
        end
      end

      context "with a problems running the scripts" do
        it_behaves_like "ran scripts"

        before do
          script2.stub(:run).and_raise 'Error in script'
          scripts[2][:run] = false
          begin
            klass.run_pending_scripts
          rescue
          end
        end
      end

      context "with a class name it cannot find" do
        let(:bad_filename) { "20140208170000_missing_class" }

        before do
          scripts[1][:run] = false
          scripts[2][:run] = false
          klass.stub pending_scripts: [script_filenames[0], bad_filename, script_filenames[1], script_filenames[2]]
          klass.run_pending_scripts
        end

        it_behaves_like "ran scripts"

        it "requires the path for the bad script" do
          path = File.join(Rails.root.join("db", "config_scripts", "#{bad_filename}.rb"))
          expect(klass).to have_received(:require).with(path)
        end

        it "outputs a name error for the missing class" do
          expect(klass).to have_received(:puts).with("Aborting: could not find class MissingClassConfig")
        end
      end
    end

    describe "list_pending_scripts" do
      before do
        klass.stub pending_scripts: ['script1.rb', 'script2.rb']
        klass.stub :puts
        klass.list_pending_scripts
      end

      it "prints out the name of each script" do
        expect(klass).to have_received(:puts).with('script1.rb')
        expect(klass).to have_received(:puts).with('script2.rb')
      end
    end
  end

  describe "creating" do
    let(:timestamp) { '20140101153500' }
    subject { klass.new(timestamp) }

    it "sets the timestamp" do
      expect(subject.timestamp).to eq timestamp
    end
  end

  describe "running" do
    let(:timestamp) { 1.day.ago.to_s(:number)}
    let(:script) { ConfigScripts::Scripts::Script.new(timestamp) }

    describe "up" do
      it "raises an exception" do
        expect(lambda{script.up}).to raise_exception("Not supported")
      end
    end

    describe "down" do
      it "raises an exception" do
        expect(lambda{script.down}).to raise_exception("Not supported")
      end
    end

    describe "run" do
      {up: true, down: false}.each do |direction, expect_timestamp|
        describe "direction" do
          before do
            if !expect_timestamp
              ConfigScripts::Scripts::ScriptHistory.record_timestamp(timestamp)
            end

            script.stub :puts
          end

          context "with a success" do
            before do
              script.stub(direction) do
                Person.create(name: 'John Doe')
              end
              script.run(direction)
            end

            it "performs the changes in the #{direction} method" do
              expect(Person.count).to eq 1
              expect(Person.first.name).to eq "John Doe"
            end

            it "{expect_timestamp ? 'adds' : 'removes'} the timestamp" do
              expect(ConfigScripts::Scripts::ScriptHistory.script_was_run?(timestamp)).to eq expect_timestamp
            end
          end

          context "with an exception in the #{direction} method" do
            before do
              script.stub(direction) do
                Person.create(name: 'John Doe')
                raise
              end
            end

            it "re-raises the exception" do
              expect(lambda{script.run(direction)}).to raise_exception
            end

            it "does not persist the changes in the #{direction} method" do
              script.run(direction) rescue nil
              expect(Person.count).to eq 0
            end

            it "does not #{expect_timestamp ? 'add' : 'remove'} the timestamp" do
              script.run(direction) rescue nil
              expect(ConfigScripts::Scripts::ScriptHistory.script_was_run?(timestamp)).not_to eq expect_timestamp
            end

            it "puts an error out to the logs" do
              script.run(direction) rescue nil
              expect(script).to have_received(:puts).with("Error running script for ConfigScripts::Scripts::Script: ")
            end
          end
        end
      end
    end
  end
end