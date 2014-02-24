describe ConfigScripts::Seeds::SeedType do
  let(:seed_set) { ConfigScripts::Seeds::SeedSet.new('test_seeds', 1) }
  let(:seed_type) { ConfigScripts::Seeds::SeedType.new(seed_set, Person, 'people') }

  describe "DSL" do
    describe "creation" do
      subject { ConfigScripts::Seeds::SeedType.new(seed_set, Person, 'people') { @val = true} }

      it "sets the attributes from the arguments" do
        expect(subject.seed_set).to eq seed_set
        expect(subject.klass).to eq Person
        expect(subject.filename).to eq 'people'
        expect(subject.instance_eval{@val}).to eq true
      end

      it "gives it an empty list of attributes" do
        expect(subject.attributes).to eq []
      end

      it "gives it the id as the identifier attributes" do
        expect(subject.identifier_attributes).to eq [:id]
      end

      it "records the associations for the model" do
        expect(subject.associations).to eq hair_color: HairColor, scope: nil
      end
    end

    describe "has_attributes" do
      it "adds the arguments to their list of attributes" do
        expect(seed_type.attributes).to be_blank
        seed_type.has_attributes :name, :hair_color
        expect(seed_type.attributes).to eq [:name, :hair_color]
      end
    end

    describe "has_identifier_attributes" do
      it "replaces their identifier attributes with the arguments" do
        seed_type.has_identifier_attributes :name, :test
        expect(seed_type.identifier_attributes).to eq [:name, :test]
      end
    end

    describe "has_scope" do
      it "adds the method and args to their list of scopes" do
        seed_type.has_scope :where, 'name=?', 'foo'
        seed_type.has_scope :order, 'name ASC'
        expect(seed_type.scopes).to eq [
          [:where, ['name=?', 'foo']],
          [:order, ['name ASC']]
        ]
      end
    end

    describe "when_writing" do
      before do
        seed_type.when_writing :name do |person|
          person.name.upcase
        end
      end

      it "adds a proc to the dynamic_writers hash" do
        expect(seed_type.dynamic_writers[:name]).not_to be_nil
      end
    end

    describe "when_reading" do
      before do
        seed_type.when_reading :name do |person|
        end
      end

      it "adds a proc to the dynamic_readers hash" do
        expect(seed_type.dynamic_readers[:name]).not_to be_nil
      end
    end
  end

  describe "reading and writing" do
    describe "write_to_folder" do
      let(:csv_file) { double }
      let(:person1) { Person.create }
      let(:person2) { Person.create }
      let(:folder) { '/tmp/seeds' }

      before do
        seed_type.stub items: [person1, person2]
        
        CSV.stub(:open) do |&block|
          block.call(csv_file)
        end
        csv_file.stub :<<

        seed_type.stub write_value_for_attribute: nil
        seed_type.stub(:write_value_for_attribute).with(person1, :color).and_return('blue')
        seed_type.stub(:write_value_for_attribute).with(person1, :shape).and_return('square')
        seed_type.stub(:write_value_for_attribute).with(person2, :color).and_return('red')
        seed_type.stub(:write_value_for_attribute).with(person2, :shape).and_return('triangle')
      end

      context "with attributes" do
        before do
          seed_type.has_attributes :color, :shape
          seed_type.write_to_folder(folder)
        end

        it "opens a CSV file" do
          expect(CSV).to have_received(:open).with('/tmp/seeds/people.csv', 'w')
        end

        it "gets the attributes for each item from write_value_for_attribute" do
          expect(seed_type).to have_received(:write_value_for_attribute).with(person1, :color)
          expect(seed_type).to have_received(:write_value_for_attribute).with(person1, :shape)
          expect(seed_type).to have_received(:write_value_for_attribute).with(person2, :color)
          expect(seed_type).to have_received(:write_value_for_attribute).with(person2, :shape)
        end

        it "writes a header to a CSV file" do
          expect(csv_file).to have_received(:<<).with([:color, :shape])
        end

        it "writes the attributes to a CSV file" do
          expect(csv_file).to have_received(:<<).with(['blue', 'square'])
          expect(csv_file).to have_received(:<<).with(['red', 'triangle'])
        end
      end

      context "with no attributes" do
        before do
          seed_type.write_to_folder(folder)
        end

        it "does not open a CSV file" do
          expect(CSV).not_to have_received(:open)
        end
      end
    end

    describe "read_from_folder" do
      let(:csv_file) { double }
      let!(:color1) { HairColor.create(color: :red) }
      let!(:color2) { HairColor.create(color: :blue) }

      let(:folder) { '/tmp/seeds' }

      before do
        CSV.stub(:open) do |&block|
          block.call(csv_file)
        end

        csv_file.stub(:each) do |&block|
          block.yield('name' => 'a', 'hair_color' => 'b')
          block.yield('name' => 'c', 'hair_color' => 'd')
        end

        seed_type.stub(:read_value_for_attribute).with('a', :name).and_return('John Doe')
        seed_type.stub(:read_value_for_attribute).with('b', :hair_color).and_return(color1)
        seed_type.stub(:read_value_for_attribute).with('c', :name).and_return('Jane Doe')
        seed_type.stub(:read_value_for_attribute).with('d', :hair_color).and_return(color2)
      end

      context "with attributes" do
        before do
          seed_type.has_attributes :name, :hair_color
          seed_type.read_from_folder(folder)
        end

        it "opens a CSV file" do
          expect(CSV).to have_received(:open).with('/tmp/seeds/people.csv', headers: true)
        end

        it "gets the attributes from read_value_for_attribute" do
          expect(seed_type).to have_received(:read_value_for_attribute).with('a', :name)
          expect(seed_type).to have_received(:read_value_for_attribute).with('b', :hair_color)
          expect(seed_type).to have_received(:read_value_for_attribute).with('c', :name)
          expect(seed_type).to have_received(:read_value_for_attribute).with('d', :hair_color)
        end

        it "creates a record for each row in the file" do
          people = Person.all
          expect(people.first.name).to eq 'John Doe'
          expect(people.first.hair_color).to eq color1
          expect(people.last.name).to eq 'Jane Doe'
          expect(people.last.hair_color).to eq color2
        end
      end

      context "with exception" do
        subject { seed_type.read_from_folder(folder) }

        before do
          $stdout.stub :puts
          Person.any_instance.stub(:save!).and_raise
          seed_type.has_attributes :name, :hair_color
        end

        it "is an exception" do
          expect{ subject }.to raise_error
        end

        it "outputs the problem file name" do
          expect($stdout).to receive(:puts).with('people.csv')
          expect{ subject }.to raise_error
        end
      end

      context "with no attributes" do
        before do
          seed_type.read_from_folder(folder)
        end

        it "does not open a CSV file" do
          expect(CSV).not_to have_received(:open)
        end
      end
    end

    describe "write_value_for_attribute" do
      let(:identifier) { "foo" }
      let(:color) { HairColor.create }
      let(:person) { Person.create(hair_color: color, name: 'Jane Doe', scope: color)}
      subject { seed_type.write_value_for_attribute(person, attribute) }

      before do
        seed_set.stub seed_identifier_for_record: identifier
      end

      context "with a dynamic writer" do
        let(:attribute) { :name }
        before do
          seed_type.when_writing :name do |person|
            person.name.upcase
          end
        end

        it "runs the block on the record, and uses the result" do
          expect(subject).to eq "JANE DOE"
        end
      end

      context "with an association" do
        let(:attribute) { :hair_color }
        it "returns the seed identifier from the seed set" do
          expect(subject).to eq identifier
          expect(seed_set).to have_received(:seed_identifier_for_record).with(color)
        end
      end

      context "with a polymorphic association" do
        let(:attribute) { :scope }

        it "returns the seed identifier from the seed set, with a class prefix" do
          expect(subject).to eq "HairColor::#{identifier}"
          expect(seed_set).to have_received(:seed_identifier_for_record).with(color)
        end
      end

      context "with a normal value" do
        let(:attribute) { :name }

        it "returns the value" do
          expect(subject).to eq person.name
        end
      end
    end

    describe "read_value_for_attribute" do
      let(:value) { 'my::value' }
      let(:color) { HairColor.create }
      subject { seed_type.read_value_for_attribute(value, attribute) }

      before do
        seed_set.stub record_for_seed_identifier: color
      end

      context "with an association" do
        let(:attribute) { :hair_color }

        it "gets the record from the seed set" do
          expect(subject).to eq color
          expect(seed_set).to have_received(:record_for_seed_identifier).with(HairColor, ['my', 'value'])
        end
      end

      context "with a polymorphic association" do
        let(:attribute) { :scope }
        let(:value) { "HairColor::my::value" }

        it "gets the record from the seed set" do
          expect(subject).to eq color
          expect(seed_set).to have_received(:record_for_seed_identifier).with(HairColor, ['my', 'value'])
        end
      end

      context "with a dynamic reader" do
        let(:attribute) { :name }

        before do
          seed_type.when_reading :name do |value|
            value + "2"
          end
        end

        it "runs the block on the value and uses the result" do
          expect(subject).to eq "my::value2"
        end
      end

      context "with a normal attribute" do
        let(:attribute) { :name }

        it "returns the value" do
          expect(subject).to eq value
        end
      end
    end

    describe "read_value_for_association" do
      let(:color) { HairColor.create }

      before do
        seed_set.stub record_for_seed_identifier: color
      end

      context "with a normal association" do
        subject { seed_type.read_value_for_association(:hair_color, ['red', 'FF0000']) }

        it "gets the record from the seed set" do
          expect(subject).to eq color
          expect(seed_set).to have_received(:record_for_seed_identifier).with(HairColor, ['red', 'FF0000'])
        end
      end

      context "with a polymorphic association" do
        subject { seed_type.read_value_for_association(:scope, ['HairColor', 'blonde', 'FFD700']) }

        it "extracts the class from the identifier and uses the seed set to get the record" do
          expect(subject).to eq color
          expect(seed_set).to have_received(:record_for_seed_identifier).with(HairColor, ['blonde', 'FFD700'])
        end
      end
    end
  end

  describe "fetching" do
    describe "items" do
      let!(:person1) { Person.create(name: 'John Doe') }
      let!(:person2) { Person.create(name: 'John Amos') }
      let!(:person3) { Person.create(name: 'Jane Doe') }

      subject { seed_type.items }

      before do
        seed_type.has_scope :where, 'name like ?', 'John%'
        seed_type.has_scope :order, 'name ASC'
      end

      it "gets the records by applying the scope" do
        expect(subject).to eq [person2, person1]
      end
    end

    describe "options" do
      it "is the seed set's options" do
        expect(seed_type.options).to eq seed_set.options
      end
    end

    describe "seed_identifier_for_record" do
      let(:record) { double }
      subject { seed_type.seed_identifier_for_record(record) }

      before do
        seed_type.has_identifier_attributes :shape, :color
        seed_type.stub(:write_value_for_attribute).with(record, :shape).and_return('triangle')
        seed_type.stub(:write_value_for_attribute).with(record, :color).and_return('red')
      end

      it "is the write values for the identifier attributes, joined with a double colon" do
        expect(subject).to eq 'triangle::red'
      end
    end

    describe "record_for_seed_identifier" do
      let!(:color1) { HairColor.create(color: 'brown', hex_value: '964B00') }
      let!(:color2) { HairColor.create(color: 'red', hex_value: 'FF0000') }
      let!(:color3) { HairColor.create(color: 'blonde', hex_value: 'FFD700') }

      let!(:person1) { Person.create(hair_color: color1, name: 'John') }
      let!(:person2) { Person.create(hair_color: color3, name: 'Jane') }
      let!(:person3) { Person.create(hair_color: color1, name: 'Jane') }
      let!(:person4) { Person.create(hair_color: color2, name: 'John') }
      let!(:person5) { Person.create(hair_color: color2, name: 'Jane') }

      subject { seed_type.record_for_seed_identifier(identifier) }

      context "with an single-field reference to another record" do
        let(:identifier) { ['brown', 'Jane'] }

        before do
          seed_type.has_identifier_attributes :hair_color, :name
          seed_set.seeds_for HairColor do
            has_identifier_attributes :color
          end
        end

        it "finds a record matching all the parts of the seed identifier" do
          expect(subject).to eq person3
        end

        it "removes all the keys from the identifier" do
          subject
          expect(identifier).to eq []
        end
      end

      context "with a multi-field reference to another record" do
        let(:identifier) { ['red','FF0000','John'] }

        before do
          seed_type.has_identifier_attributes :hair_color, :name
          seed_set.seeds_for HairColor do
            has_identifier_attributes :color, :hex_value
          end
        end

        it "finds a record matching all the parts of the seed identifier" do
          expect(subject).to eq person4
        end

        it "removes all the keys from the identifier" do
          subject
          expect(identifier).to eq []
        end
      end

      context "with more fields in the identifier than it needs" do
        let(:identifier) { ['red','FF0000','John', 'test'] }

        before do
          seed_type.has_identifier_attributes :hair_color, :name
          seed_set.seeds_for HairColor do
            has_identifier_attributes :color, :hex_value
          end
        end

        it "finds a record matching all the parts of the seed identifier" do
          expect(subject).to eq person4
        end

        it "removes all the keys it needs from the identifier" do
          subject
          expect(identifier).to eq ['test']
        end
      end
    end
  end
end