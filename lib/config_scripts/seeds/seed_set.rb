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
          @registered_sets ||= []
          self.load_seed_sets
          self.registered_sets.sort do |set1, set2|
            set1.order <=> set2.order
          end.each do |set|
            set.write
          end
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

      def seeds_for(klass, filename=nil, &block)
        filename ||= klass.name.underscore
        @seed_types[klass] = SeedType.new(self, klass, filename, &block)
      end

      def set_seed_params_for_class(klass, params)
        @seed_params[klass] = params
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
    end
  end
end