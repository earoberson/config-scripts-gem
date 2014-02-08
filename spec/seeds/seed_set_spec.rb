describe ConfigScripts::Seeds::SeedSet do
  let(:klass) { ConfigScripts::Seeds::SeedSet }
  describe "loading" do
    describe "register_seed_set" do
      it "adds the seed set to the class list" do
        seed_set = double
        klass.register_seed_set(seed_set)
        expect(klass.registered_sets).to include seed_set
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
      klass.instance_eval { @registered_sets = [] }
      seed_sets.each do |set|
        set.stub(write: true, read: true, order: 0)
        klass.register_seed_set(set)
      end
    end

    describe "write" do
      it "calls the write method on each seed set" do
        klass.write
        seed_sets.each { |set| expect(set).to have_received(:write) }
      end
    end

    describe "read" do
      it "calls the read method on each seed set" do
        klass.read
        seed_sets.each { |set| expect(set).to have_received(:read) }
      end
    end
  end

  describe "instance reading and writing" do
    let(:set) { klass.new('test_seeds', 1) {} }
    let!(:seed_type) { double }
    let(:seed_folder) { Rails.root.join('db', 'seeds', 'data', 'test_seeds') }

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
        expect(set).to have_received(:puts).with("Writing seeds to #{seed_folder}")
      end
    end

    describe "read" do
      before do
        set.read
      end

      it "creates the seed folder" do
        expect(FileUtils).to have_received(:mkdir_p).with(seed_folder)
      end

      it "says where it's reading the seeds from" do
        expect(set).to have_received(:puts).with("Reading seeds from #{seed_folder}")
      end

      it "reads all of the seed types from the folder" do
        expect(seed_type).to have_received(:read_from_folder).with(seed_folder)
      end
    end
  end

  describe "DSL" do
    describe "creation" do
      before do
        klass.instance_eval { @registered_sets = [] }
      end

      subject { klass.new('test_seeds', 5, setting: 'value') { @val = true } }

      it "sets the name" do
        expect(subject.name).to eq 'test_seeds'
      end

      it "sets the order" do
        expect(subject.order).to eq 5
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
        expect(klass.registered_sets).to include subject
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
      let(:record) { double }
      subject { set.record_for_seed_identifier(klass, identifier) }

      before do
        seed_type.stub record_for_seed_identifier: record
      end

      context "for a class it has seed types for" do
        let(:klass) { Person }
        it "gets the record from the seed type" do
          expect(subject).to eq record
          expect(seed_type).to have_received(:record_for_seed_identifier).with(identifier)
        end

        it "caches the result" do
          subject
          set.record_for_seed_identifier(klass, identifier)
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
          subject
          set.record_for_seed_identifier(klass, identifier)
          expect(seed_type).to have_received(:record_for_seed_identifier).once
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