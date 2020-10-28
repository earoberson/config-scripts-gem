describe ConfigScripts::Scripts::ScriptHistory do
  let(:klass) { ConfigScripts::Scripts::ScriptHistory }
  let(:timestamp1) { 5.minutes.ago.to_s(:number) }
  let(:timestamp2) { 10.minutes.ago.to_s(:number) }

  describe "entries_for_timestamp" do
    let!(:entry1) { klass.create(script_name: timestamp1) }
    let!(:entry2) { klass.create(script_name: timestamp1) }
    let!(:entry3) { klass.create(script_name: timestamp2) }

    subject { klass.entries_for_timestamp(timestamp1) }

    it "gets all the entries whose timestamp has the value given" do
      expect(subject).to include entry1
      expect(subject).to include entry2
    end

    it "does not include entries with other timestamps" do
      expect(subject).not_to include entry3
    end
  end

  describe "script_was_run?" do
    let!(:entry1) { klass.create(script_name: timestamp2) }

    context "with a timestamp that has an entry in the table" do
      subject { klass.script_was_run?(timestamp2) }
      it { is_expected.to eq(true) }
    end

    context "with a timestamp that has no entry in the table" do
      subject { klass.script_was_run?(timestamp1) }
      it { is_expected.to eq(false) }
    end
  end

  describe "record_timestamp" do
    it "adds an entry to the table" do
      expect(klass.script_was_run?(timestamp1)).to eq(false)
      klass.record_timestamp(timestamp1)
      expect(klass.script_was_run?(timestamp1)).to eq(true)
    end
  end

  describe "remove_timestamp" do
    it "removes the entry from the table" do
      klass.create(script_name: timestamp2)
      expect(klass.script_was_run?(timestamp2)).to eq(true)
      klass.remove_timestamp(timestamp2)
      expect(klass.script_was_run?(timestamp2)).to eq(false)
    end
  end
end