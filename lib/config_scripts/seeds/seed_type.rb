require 'csv'

module ConfigScripts
  module Seeds
    # This class encapsulates information about how to write seeds for a class
    # to a seed file.
    class SeedType
      # @!group Attributes

      # @return [SeedSet]
      # The seed set that this type has been defined within.
      attr_reader :seed_set

      # @return [Class]
      # The model class whose records we are storing in this seed file.
      attr_reader :klass

      # @return [String]
      # The name of the file that we will store these records in.
      attr_reader :filename

      # @return [Array<Symbol>]
      # The names of the attributes on the model object that we store in the
      # seed file.
      attr_reader :attributes

      # @return [Array<Symbol>]
      # The names of the attributes used to compose a unique identifier for
      # a record.
      attr_reader :identifier_attributes

      # @return [Array]
      # The active record associations for the model class for this seed file.
      attr_reader :associations

      # @return [Hash<Symbol, Proc>]
      # The attributes that we generate dynamically after loading the ones from
      # the seed file.
      attr_reader :dynamic_readers

      # @return [Hash<Symbol, Proc>]
      # The attributes that we generate dynamically when writing things to the
      # seed file.
      attr_reader :dynamic_writers

      # @return [Array<Array>]
      # The scopes that we apply when fetching items.
      #
      # Each entry will be an array. The first entry in the inner arrays will
      # be a symbol, the name of a method that can be run on a relation. The 
      # result of the array will be passed in when running the method on the
      # scope.
      attr_reader :scopes

      # @!group Creation

      # This method creates a new seed type.
      #
      # This method should be given a block, which will be run in the instance
      # context of the new seed type. That block should use the DSL methods to
      # fill in the details for the seed type.
      #
      # @param [SeedSet] seed_set
      #   The seed set that this seed type is defined within.
      #
      # @param [Class] klass
      #   The model class whose data we are running.
      #
      # @param [String] filename
      #   The name of the file in which the seed data will be stored.
      def initialize(seed_set, klass, filename, &block)
        @seed_set = seed_set
        @klass = klass
        @filename = filename
        @attributes = []
        @identifier_attributes = [:id]
        @scopes = []
        @dynamic_writers = {}
        @dynamic_readers = {}

        @associations = {}
        @klass.reflect_on_all_associations.each do |association|
          @associations[association.name] = association.klass rescue nil
        end

        self.instance_eval(&block) if block_given?
      end

      # @!group DSL

      # This method adds new attributes to the ones written in this seed type.
      #
      # @param [Array<Symbol>] new_attributes
      #   The attributes to add.
      #
      # @return [Array<Symbol>]
      #   The full list of attributes after the new ones are added.
      def has_attributes(*new_attributes)
        @attributes += new_attributes
      end

      # This method defines the attributes used to generate a unique identifier
      # for a record.
      #
      # @param [Array<Symbol>] attributes
      #   The attributes that form the unique identifier.
      #
      # @return [Array<Symbol>]
      #   The attributes.
      def has_identifier_attributes(*attributes)
        @identifier_attributes = attributes
      end

      # This method adds a scope to the list used to filter the records for
      # writing.
      #
      # @param [Symbol] method
      #   The name of the method to call on the relation.
      #
      # @param [Array] args
      #   The arguments that will be passed into the scope method on the
      #   relation.
      #
      # @return [Array]
      #   The full list of scopes.
      def has_scope(method, *args)
        @scopes << [method, args]
      end

      # This method registers a custom block that will be run when reading a
      # value from the seed file.
      #
      # This method takes a block that will be run on the value from the seed
      # file. The return value of the block will be used in place of the
      # original value from the seed file.
      #
      # @param [Symbol] attribute
      #   The attribute that we are reading.
      def when_reading(attribute, &block)
        @dynamic_readers[attribute] = block
      end

      # This method registers a custom block that will be run when writing a
      # value to the seed file.
      #
      # This method takes a block that will be run on the item whose values we
      # are writing. The return value of the block will be used instead of
      # running the method on the record.
      #
      # @param [Symbol] attribute
      #   The attribute we are writing.
      def when_writing(attribute, &block)
        @dynamic_writers[attribute] = block
      end

      # @!group Reading and Writing

      # This method writes the seed data file to a folder.
      #
      # This will write a header row with the names of the attributes, and then
      # write a row for each item from the {#items} method. It will use the
      # {#write_value_for_attribute} method to get the values for the CSV file.
      #
      # If this seed type has no attributes, this method will not write
      # anything.
      #
      # @param [String] folder
      #   The full path to the folder to write to.
      def write_to_folder(folder)
        return unless attributes.any?
        CSV.open(File.join(folder, "#{self.filename}.csv"), 'w') do |csv|
          csv << self.attributes
          self.items.each do |item|
            data = self.attributes.collect { |attribute| self.write_value_for_attribute(item, attribute) }
            csv << data
          end
        end
      end

      # This method reads the seed data from a file, and creates new records
      # from it.
      #
      # This will extract all the rows from the CSV file, and use
      # {#read_value_for_attribute} to get the attributes for the record from
      # each cell in the CSV file.
      #
      # If this seed type has no attributes, this method will not try to read
      # the file.
      #
      # @param [String] folder
      #   The full path to the folder with the seed files.
      def read_from_folder(folder)
        return unless attributes.any?
        CSV.open(File.join(folder, "#{self.filename}.csv"), headers: true) do |csv|
          csv.each do |row|
            record = self.klass.new
            row.each do |attribute, value|
              attribute = attribute.to_sym
              value = self.read_value_for_attribute(value, attribute)
              record.send("#{attribute}=", value)
            end
            record.save!
          end
        end
      end

      # This method gets the value that we should write into the CSV file for
      # an attribute.
      #
      # If the value for that attribute is another model record, this will get
      # its seed identifier from the seed set. Otherwise, it will just use the
      # value.
      #
      # @param [ActiveRecord::Base] item
      #   The record whose value we are getting.
      #
      # @param [Symbol] attribute
      #   The attribute we are getting.
      #
      # @return [String]
      #   The value to write.
      def write_value_for_attribute(item, attribute)
        if @dynamic_writers[attribute]
          value = @dynamic_writers[attribute].call(item)
        else
          value = item.send(attribute)
        end

        if value.is_a?(ActiveRecord::Base)
          value = self.seed_set.seed_identifier_for_record(value)
        end
        value
      end

      # This method takes a value from the CSV file and gives back the value
      # that should be set on the record.
      #
      # @param [String] value
      #   The value from the CSV file.
      #
      # @param [Symbol] attribute
      #   The name of the attribute that we are formatting.
      #
      # @return [Object]
      #   The value to set on the record.
      def read_value_for_attribute(value, attribute)
        if @dynamic_readers[attribute]
          value = @dynamic_readers[attribute].call(value)
        end

        if @associations[attribute]
          value = self.seed_set.record_for_seed_identifier(@associations[attribute], value)
        end
        value
      end

      # @!group Fetching

      # This method gets a relation encompassing all the records in the class.
      #
      # We encapsulate this here so that we can use different calls in Rails 3
      # and Rails 4.
      #
      # @return [Relation]
      def all
        version = Rails.version[0]
        records = version == '3' ? self.klass.scoped : self.klass.all
      end
      # This method gets the items that we should write to our seed file.
      #
      # It will start with the scoped list for the model class, and then apply
      # all the scopes in our {#scopes} list.
      #
      # @return [Relation]
      def items
        records = self.all
        self.scopes.each { |method, args| records = records.send(method, *args) }
        records
      end

      # This method gets the additional information passed in when defining our
      # seed set.
      #
      # @return [Hash]
      def options
        self.seed_set.options
      end

      # @!group Seed Identifiers

      # This method gets the unique identifier for a record of the class that
      # this seed type handles.
      #
      # @param [ActiveRecord::Base] record
      #   The record
      #
      # @return [String]
      #   The identifier for the seed files.
      def seed_identifier_for_record(record)
        self.identifier_attributes.collect { |param| self.write_value_for_attribute(record, param) }.join("::")
      end

      # This method finds a record for our model class based on the unique seed
      # identifier.
      #
      # @param [String] identifier
      #   The identifier from the CSV file.
      #
      # @return [ActiveRecord::Base]
      #   The record
      def record_for_seed_identifier(identifier)
        return nil if identifier.blank?
        records = self.all
        values = identifier.split("::")
        self.identifier_attributes.each_with_index do |attribute, index|
          value = values[index]
          if self.associations[attribute]
            association_record = self.seed_set.record_for_seed_identifier(@associations[attribute], value)
            records = records.where(attribute => association_record)
          else
            records = records.where(attribute => value)
          end
        end
        records.first
      end
    end
  end
end