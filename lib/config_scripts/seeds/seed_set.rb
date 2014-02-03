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
      # The order in which this seed set should be run.
      # Seed sets will be run from the one with the lowest order to the
      # highest.
      attr_reader :order

      # @return [Hash]
      # Arbitrary extra data passed in when defining the seed set.
      attr_reader :options

      # @return [Hash]
      # A hash mapping class names to the {SeedType} instances describing how
      # to handle seeds for that class within this set.
      attr_reader :seed_types

      class << self
        # @!group Registration

        # @return [Array<SeedSet>]
        # The seed sets that have been defined.
        attr_reader :registered_sets

        # This method adds a new seed set to our registry.
        #
        # @param [SeedSet] set
        #   The new seed set.
        #
        # @return [Array<SeedSet>]
        def register_seed_set(set)
          @registered_sets ||= []
          @registered_sets << set
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
        # @return [Array]
        def write
          self.each_set(&:write)
        end

        # This method loads the data from every seed set into the database.
        # @return [Array]
        def read
          self.each_set(&:read)
        end

        # This method runs a block on each set that the app has defined.
        #
        # The block will be given one parameter, which is the seed set.
        #
        # @return [Array]
        def each_set(&block)
          @registered_sets ||= []
          self.load_seed_sets
          self.registered_sets.sort do |set1, set2|
            set1.order <=> set2.order
          end.each(&block)
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
      # @param [Integer] order
      #   The order in which this seed set should be run.
      #
      # @param [Hash] options
      #   Additional information that can be made accessible to the seed type
      #   definitions.
      def initialize(name, order, options = {}, &block)
        @name = name.to_s
        @order = order
        @options = options
        @seed_types = {}
        self.instance_eval(&block)
        ConfigScripts::Seeds::SeedSet.register_seed_set(self)
      end

      # @!group Reading and Writing

      # This method writes the data for this seed set to its seed folder.
      #
      # It will create the folder and then write the file for each seed type
      # that has been defined.
      def write
        folder = Rails.root.join('db', 'seeds', 'data', self.name)
        FileUtils.mkdir_p(folder)
        puts "Writing seeds to #{folder}"
        self.seed_types.each do |klass, seed_type|
          seed_type.write_to_folder(folder)
        end
      end

      # This method reads the data for this seed set from its seed folder.
      #
      # It will load the data for each seed type's file, enclosing all the
      # seed types in a transaction block.
      def read
        folder = Rails.root.join('db', 'seeds', 'data', self.name)
        FileUtils.mkdir_p(folder)
        puts "Reading seeds from #{folder}"
        ActiveRecord::Base.transaction do
          self.seed_types.each do |klass, seed_type|
            seed_type.read_from_folder(folder)
          end
        end
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

      # @!group Seed Identifiers

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
        klass = record.class
        while klass != ActiveRecord::Base
          seed_type = self.seed_types[klass]
          if seed_type
            return seed_type.seed_identifier_for_record(record)
          end
          klass = klass.superclass
        end
        record.id
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
      # @param [String] identifier
      #   The identifier from the seed data.
      #
      # @return [ActiveRecord::Base]
      #   The model record.
      #
      # @todo Add handling of missing seed types, and seed types for
      #   superclasses.
      def record_for_seed_identifier(klass, identifier)
        @record_cache ||= {}
        @record_cache[klass] ||= {}
        record = @record_cache[klass][identifier]
        return record if record
        record = self.seed_types[klass].record_for_seed_identifier(identifier)
        @record_cache[klass][identifier] = record
        record
      end
    end
  end
end