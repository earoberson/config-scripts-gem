module ConfigScripts
  module Seeds
    # This class represents a set of related seeds.
    #
    # These seeds will be stored as CSV files in a folder together.
    class SeedSet
      # @return [String]
      # The name of the folder for this seed set.
      attr_reader :name

      # @return [Integer]
      # A number identifying this set. Seed sets will be run from the one with
      # the lowest number to the highest.
      attr_accessor :set_number

      # @return [String]
      # The name of the folder to which we will write the seeds.
      attr_reader :folder

      # @return [Hash]
      # Arbitrary extra data passed in when defining the seed set.
      attr_reader :options

      # @return [Hash]
      # A hash mapping class names to the {SeedType} instances describing how
      # to handle seeds for that class within this set.
      attr_reader :seed_types

      # @return [Proc]
      # The block that will be run when resetting the records during a load.
      attr_reader :reset_block

      class << self
        # @!group Registration

        # @return [Hash<Integer, SeedSet>]
        # The seed sets that have been defined.
        attr_reader :registered_sets

        # This method adds a new seed set to our registry.
        #
        # If there is already a registered seed set with this set's set_number,
        # the number will be incremented until it is available.
        #
        # @param [SeedSet] set
        #   The new seed set.
        #
        # @return [SeedSet]
        def register_seed_set(set)
          @registered_sets ||= {}
          while @registered_sets[set.set_number]
            return if @registered_sets[set.set_number] == set
            set.set_number += 1
          end
          @registered_sets[set.set_number] = set
        end

        # This method wipes out our records of registered seed sets.
        #
        # @return [Hash]
        #   The new list of seed sets.
        def clear_registered_sets
          @registered_sets = {}
        end

        # This method loads all of the seed definitions from the files in the
        # +db/seeds/definitions+ directory.
        def load_seed_sets
          Dir[Rails.root.join('db', 'seeds', 'definitions', '*')].each do |file|
            require file
          end
        end

        # @!group Batch Operations

        # This method writes the data for every seed set to its seed data
        # folder.
        #
        # @param [Integer] set_number
        #   The number of the set to write.
        #
        # @return [Array]
        def write(set_number=nil)
          self.each_set(set_number, &:write)
        end

        # This method loads the data from every seed set into the database.
        #
        # @param [Integer] set_number
        #   The number of the set to read.
        #
        # @return [Array]
        def read(set_number=nil)
          self.each_set set_number do |set|
            set.read(set_number.present?)
          end
        end

        # This method lists every seed set, with its set number.
        # @return [Array]
        def list
          self.each_set do |set|
            puts "#{set.set_number}: #{set.name}"
          end
        end

        # This method runs a block on each set that the app has defined.
        #
        # The block will be given one parameter, which is the seed set.
        #
        # @param [String] set_number
        #   The number of the set that we should run.
        #
        # @return [Array]
        def each_set(set_number=nil, &block)
          @registered_sets ||= {}
          self.load_seed_sets
          if set_number
            if self.registered_sets[set_number]
              block.call(self.registered_sets[set_number])
            end
          else
            self.registered_sets.keys.sort.each do |set_number|
              block.call(self.registered_sets[set_number])
            end
          end
        end
      end

      # @!group Creation

      # This method creates a new seed set.
      #
      # It should be given a block, which will be run on the instance, and
      # which should use the {#seeds_for} method to define seed types.
      #
      # @param [String] name
      #   The name for the folder for the seeds.
      #
      # @param [Integer] set_number
      #   The set_number in which this seed set should be run.
      #
      # @param [String] folder
      #   The folder that we should use for this seed set. If this is not
      #   provided, we will use the name.
      #
      # @param [Hash] options
      #   Additional information that can be made accessible to the seed type
      #   definitions.
      def initialize(name, set_number=1, folder=nil, options = {}, &block)
        @name = name.to_s
        @set_number = set_number
        @folder = folder || @name
        @options = options
        @seed_types = {}
        self.instance_eval(&block) if block_given?
        ConfigScripts::Seeds::SeedSet.register_seed_set(self)
      end

      # @!group Reading and Writing

      # This method writes the data for this seed set to its seed folder.
      #
      # It will create the folder and then write the file for each seed type
      # that has been defined.
      def write
        folder_path = Rails.root.join('db', 'seeds', 'data', self.folder)
        FileUtils.mkdir_p(folder_path)
        puts "Writing seeds for #{self.name} to #{folder_path}"
        self.seed_types.each do |klass, seed_type|
          seed_type.write_to_folder(folder_path)
        end
      end

      # This method reads the data for this seed set from its seed folder.
      #
      # @param [Boolean] reset
      #   Whether we should reset the existing records before loading the seeds.
      #
      # It will load the data for each seed type's file, enclosing all the
      # seed types in a transaction block.
      def read(reset=false)
        folder_path = Rails.root.join('db', 'seeds', 'data', self.folder)
        FileUtils.mkdir_p(folder_path)
        puts "Reading seeds for #{self.name} from #{folder_path}"
        ActiveRecord::Base.transaction do
          self.reset_records if reset
          self.seed_types.each do |klass, seed_type|
            seed_type.read_from_folder(folder_path)
          end
        end
      end

      # This method resets all the existing records that could be populated by
      # this seed set.
      def reset_records
        self.reset_block.call if self.reset_block
      end

      # @!group DSL

      # This method defines a new seed type within this seed set.
      #
      # This method should be given a block, which will be passed to the
      # initializer for the new seed type.
      #
      # @param [Class] klass
      #   The model class whose seed data this stores.
      #
      # @param [String] filename
      #   The name of the file in which the seed data should be stored.
      #   If this is not provided, it will use the name of the class.
      #   This should not include the file extension.
      #
      # @return [SeedType]
      def seeds_for(klass, filename=nil, &block)
        filename ||= klass.name.underscore.pluralize
        @seed_types[klass] = SeedType.new(self, klass, filename, &block)
      end

      # This method defines a block that will be run when resetting existing
      # records.
      #
      # This block will be run when loading a seed set as a one-off, but not
      # when loading all the seed sets.
      #
      # @return [Proc]
      def when_resetting(&block)
        @reset_block = block
      end

      # @!group Seed Identifiers

      # This method gets a seed type that we have on file for a class.
      #
      # @param [Class] klass
      #   The class whose seeds we are dealing with.
      #
      # @return [SeedType]
      def seed_type_for_class(klass)
        while klass && klass != ActiveRecord::Base
          seed_type = self.seed_types[klass]
          if seed_type
            return seed_type
          end
          klass = klass.superclass
        end
      end


      # This method gets a unique identifier for a record when writing seeds
      # that refer to it.
      #
      # It will look for a seed type that handles seeds for a class in the
      # record's class heirarchy, and use that seed type's
      # {#seed_identifier_for_record} method. If it cannot find a seed type,
      # it will use the record's ID.
      #
      # @param [ActiveRecord::Base] record
      #   The record whose identifier we are generating.
      #
      # @return [String]
      def seed_identifier_for_record(record)
        seed_type = self.seed_type_for_class(record.class)
        if seed_type
          seed_type.seed_identifier_for_record(record)
        else
          record.id rescue nil
        end
      end

      # This method finds a record based on a unique identifier in the seed
      # data.
      #
      # This will look for a seed type for the class, and use its
      # {#record_for_seed_identifier} method to get the record.
      #
      # The result of this will be memoized so that we do not have to keep
      # looking up the records.
      #
      # @param [Class] klass
      #   The model class for the record we are finding.
      #
      # @param [Array<String>] identifier
      #   The identifier components from the seed data.
      #
      # @return [ActiveRecord::Base]
      #   The model record.
      def record_for_seed_identifier(klass, identifier)
        seed_type = self.seed_type_for_class(klass)
        return nil unless seed_type

        @record_cache ||= {}
        @record_cache[klass] ||= {}

        cache_identifier = identifier.dup

        while cache_identifier.any?
          record = @record_cache[klass][cache_identifier]
          if record
            cache_identifier.count.times { identifier.shift }
            return record
          end
          cache_identifier.pop
        end

        if seed_type
          cache_identifier = identifier.dup
          record = seed_type.record_for_seed_identifier(identifier)

          if identifier.any?
            cache_identifier = cache_identifier[0...-1*identifier.count]
          end

          @record_cache[klass][cache_identifier] = record
        end
        record
      end
    end
  end
end