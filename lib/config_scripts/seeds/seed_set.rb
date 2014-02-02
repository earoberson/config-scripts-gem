require 'csv'

module ConfigScripts
  module Seeds
    class SeedSet
      attr_reader :name
      attr_reader :order
      attr_reader :options
      attr_reader :seed_types

      class << self
        attr_reader :registered_sets

        def register_seed_set(set)
          @registered_sets ||= []
          @registered_sets << set
        end

        def write
          self.each_set(&:write)
        end

        def read
          self.each_set(&:read)
        end

        def each_set(&block)
          @registered_sets ||= []
          self.load_seed_sets
          self.registered_sets.sort do |set1, set2|
            set1.order <=> set2.order
          end.each(&block)
        end

        def load_seed_sets
          Dir[Rails.root.join('db', 'seeds', 'definitions', '*')].each do |file|
            require file
          end
        end
      end

      def initialize(name, order, options = {}, &block)
        @name = name.to_s
        @order = order
        @options = options
        @seed_types = {}
        self.instance_eval(&block)
        ConfigScripts::Seeds::SeedSet.register_seed_set(self)
      end

      def write
        folder = Rails.root.join('db', 'seeds', 'data', self.name)
        FileUtils.mkdir_p(folder)
        puts "Writing seeds to #{folder}"
        self.seed_types.each do |klass, seed_type|
          seed_type.write_to_folder(folder)
        end
      end

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

      def seeds_for(klass, filename=nil, &block)
        filename ||= klass.name.underscore.pluralize
        @seed_types[klass] = SeedType.new(self, klass, filename, &block)
      end

      def seed_param_for_record(record)
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

      def record_for_seed_identifier(klass, param)
        @record_cache ||= {}
        @record_cache[klass] ||= {}
        record = @record_cache[klass][param]
        return record if record
        record = self.seed_types[klass].record_for_seed_identifier(param)
        @record_cache[klass][param] = record
        record
      end
    end
  end
end