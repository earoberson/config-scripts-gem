describe ConfigScripts::Seeds::SeedSet do
  let(:klass) { ConfigScripts::Seeds::SeedSet }
  describe "loading" do
    describe "register_seed_set" do
      before do
        klass.clear_registered_sets
      end

      it "adds the seed set to the class list" do
        seed_set = double(set_number: 1)
        klass.register_seed_set(seed_set)
        expect(klass.registered_sets).to eq 1 => seed_set
      end

      context "with a duplicate set number" do
        it "increments the number until it has a unique one" do
          seed_set_1 = klass.new 'set_1', 1
          seed_set_2 = klass.new 'set_2', 1
          expect(seed_set_2.set_number).to eq 2
        end
      end
    end

    describe "load_seed_sets" do
      it "requires all the files in the seed definitions folder" do
        definitions_path = Rails.root.join('db', 'seeds', 'definitions', '*')
        seed_files = ['/tmp/file1', '/tmp/file2']
        Dir.stub(:[]).with(definitions_path).and_return(seed_files)
        klass.stub :require
        klass.load_seed_sets
        expect(Dir).to have_received(:[]).with(definitions_path)
        seed_files.each do |file|
          expect(klass).to have_received(:require).with(file)
        end
      end
    end
  end

  describe "batch operations" do
    let(:seed_sets) { [double, double] }
    before do
      klass.clear_registered_sets
      klass.stub :puts
      seed_sets.each_with_index do |set, index|
        set.stub(
          write: true,
          read: true,
          set_number: (index + 1) * 2,
          name: "Seed Set #{index + 1}",
          reset_records: true
        )
        klass.register_seed_set(set)
      end
    end

    describe "write" do
      context "with no argument" do
        it "calls the write method on each seed set" do
          klass.write
          seed_sets.each { |set| expect(set).to have_received(:write) }
        end
      end

      context "with an argument" do
        it "calls the write method on the set whose number is given" do
          klass.write(2)
          expect(seed_sets.first).to have_received(:write)
          expect(seed_sets.last).not_to have_received(:write)
        end
      end
    end

    describe "read" do
      context "with no argument" do
        it "calls the read method on each seed set, telling it not to reset" do
          klass.read
          seed_sets.each { |set| expect(set).to have_received(:read).with(false) }
        end
      end

      context "with an argument" do
        it "calls the read method on the set whose number is given, telling it to reset" do
          klass.read(4)
          expect(seed_sets.last).to have_received(:read).with(true)
          expect(seed_sets.first).not_to have_received(:read)
        end
      end
    end

    describe "list" do
      it "prints the set number and name for each seed set" do
        klass.list
        expect(klass).to have_received(:puts).with("2: Seed Set 1")
        expect(klass).to have_received(:puts).with("4: Seed Set 2")
      end
    end
  end

  describe "instance reading and writing" do
    let(:set) { klass.new('test_seeds', 1, 'my_seeds') }
    let!(:seed_type) { double }
    let(:seed_folder) { Rails.root.join('db', 'seeds', 'data', 'my_seeds') }

    before do
      FileUtils.stub :mkdir_p
      set.stub :seed_types => {Person: seed_type}
      seed_type.stub write_to_folder: nil, read_from_folder: true
      set.stub :puts
    end

    describe "write" do
      before do
        set.write
      end

      it "creates the seed folder" do
        expect(FileUtils).to have_received(:mkdir_p).with(seed_folder)
      end

      it "writes all of the seed types to the folder" do
        expect(seed_type).to have_received(:write_to_folder).with(seed_folder)
      end

      it "says where it's writing the seeds to" do
        expect(set).to have_received(:puts).with("Writing seeds for test_seeds to #{seed_folder}")
      end
    end

    describe "read" do
      before do
        set.stub :reset_records
      end

      context do
        before do
          set.read
        end

        it "creates the seed folder" do
          expect(FileUtils).to have_received(:mkdir_p).with(seed_folder)
        end

        it "says where it's reading the seeds from" do
          expect(set).to have_received(:puts).with("Reading seeds for test_seeds from #{seed_folder}")
        end

        it "reads all of the seed types from the folder" do
          expect(seed_type).to have_received(:read_from_folder).with(seed_folder)
        end
      end

      context "when resetting" do
        it "resets the records" do
          set.read(true)
          expect(set).to have_received(:reset_records)
        end
      end

      context "when not resetting" do
        it "does not reset the records" do
          set.read(false)
          expect(set).not_to have_received(:reset_records)
        end
      end
    end
  end

  describe "DSL" do
    describe "creation" do
      before do
        klass.clear_registered_sets
      end

      subject { klass.new('test_seeds', 5, 'my_seeds', setting: 'value') { @val = true } }

      it "sets the name" do
        expect(subject.name).to eq 'test_seeds'
      end

      it "sets the set number" do
        expect(subject.set_number).to eq 5
      end

      it "sets the folder" do
        expect(subject.folder).to eq 'my_seeds'
      end

      it "sets the options" do
        expect(subject.options).to eq(setting: 'value')
      end

      it "runs the block on the instance" do
        expect(subject.instance_eval{@val}).to eq true
      end

      it "gives it an empty hash of seed types" do
        expect(subject.seed_types).to eq({})
      end

      it "registers the set with the klass" do
        expect(klass.registered_sets[subject.set_number]).to eq subject
      end
    end

    describe "seeds_for" do
      let(:set) { ConfigScripts::Seeds::SeedSet.new('test_seeds', 1) }

      subject { set.seeds_for(Person, 'people_seeds') { @val = true } }

      it "constructs a seed type with the arguments" do
        expect(subject).to be_a ConfigScripts::Seeds::SeedType
        expect(subject.klass).to eq Person
        expect(subject.filename).to eq 'people_seeds'
        expect(subject.instance_eval {@val}).to eq true
      end

      it "maps the seed type to the class in the seed type list" do
        subject
        expect(set.seed_types[Person]).to eq subject
      end

      it "has a default filename based on the class name" do
        seeds = set.seeds_for(Person)
        expect(seeds.filename).to eq 'people'
      end
    end

    describe "when_resetting" do
      let(:set) { ConfigScripts::Seeds::SeedSet.new('test_seeds', 1) }

      it "sets the reset_block value" do
        value = 0
        set.when_resetting do
          value = 1
        end
        expect(value).to eq 0
        set.reset_records
        expect(value).to eq 1
      end
    end
  end

  describe "seed identifiers" do
    let(:set) { ConfigScripts::Seeds::SeedSet.new('test_seeds', 1) }
    let(:seed_type) { set.seeds_for(Person) }
    let(:identifier) { double }

    class AdultPerson < Person
    end

    describe "seed_identifier_for_record" do

      subject { set.seed_identifier_for_record(record) }

      before do
        seed_type.stub :seed_identifier_for_record => identifier
      end

      context "with a record it has a seed type for" do
        let(:record) { Person.new }

        it "gets the identifier from the seed types" do
          expect(subject).to eq identifier
          expect(seed_type).to have_received(:seed_identifier_for_record).with(record)
        end
      end

      context "with a record where it has a seed type for a superclass" do
        let(:record) { AdultPerson.new }

        it "gets the identifier from the seed types" do
          expect(subject).to eq identifier
          expect(seed_type).to have_received(:seed_identifier_for_record).with(record)
        end
      end

      context "with a record it does not have a seed type for" do
        let(:record) { ConfigScripts::Scripts::ScriptHistory.new(id: 5) }

        it "is the record's id" do
          expect(subject).to eq 5
        end
      end

      context "with a record that is not a subclass of ActiveRecord" do
        let(:record) { "Hello" }

        it "is nil" do
          expect(subject).to be_nil
        end
      end
    end

    describe "record_for_seed_identifier" do
      let(:record) { Person.create }
      let(:identifier) { ['red', 'John'] }
      subject { set.record_for_seed_identifier(klass, identifier) }

      before do
        seed_type.stub :record_for_seed_identifier do |identifier|
          identifier.shift
          identifier.shift
          record
        end
        seed_type.has_identifier_attributes :hair_color, :name
      end

      context "for a class it has seed types for" do
        let(:klass) { Person }
        it "gets the record from the seed type" do
          expect(subject).to eq record
          expect(seed_type).to have_received(:record_for_seed_identifier).with(identifier)
        end

        it "caches the result" do
          identifier2 = identifier.dup
          subject
          set.record_for_seed_identifier(klass, identifier2)
          expect(seed_type).to have_received(:record_for_seed_identifier).once
        end
      end

      context "for a class where it has seed types for a parent class" do
        let(:klass) { AdultPerson }
        it "gets the record from the seed type" do
          expect(subject).to eq record
          expect(seed_type).to have_received(:record_for_seed_identifier).with(identifier)
        end

        it "caches the result" do
          identifier2 = identifier.dup
          subject
          set.record_for_seed_identifier(klass, identifier2)
          expect(seed_type).to have_received(:record_for_seed_identifier).once
        end
      end

      context "with an identifier that has more keys than needed" do
        let(:klass) { Person }
        let(:identifier) { ['red', 'John', 'Smith'] }

        it "only caches it with the keys needed" do
          subject
          set.record_for_seed_identifier(klass, ['red', 'John'])
          expect(seed_type).to have_received(:record_for_seed_identifier).once
        end

        it "removes the keys it needs from the identifier" do
          subject
          expect(identifier).to eq ['Smith']
        end

        it "removes the keys it needs even on a cache hit" do
          identifier2 = identifier.dup
          subject
          set.record_for_seed_identifier(klass, identifier2)
          expect(seed_type).to have_received(:record_for_seed_identifier).once
          expect(identifier2).to eq ['Smith']
        end
      end

      context "for class where it does not have a seed type" do
        let(:klass) { ConfigScripts::Scripts::ScriptHistory }

        it "is nil" do
          expect(subject).to be_nil
        end
      end
    end
  end
end