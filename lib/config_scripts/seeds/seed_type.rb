require 'csv'

module ConfigScripts
  module Seeds
    class SeedType
      attr_reader :seed_set
      attr_reader :klass
      attr_reader :filename
      attr_reader :attributes
      attr_reader :seed_params

      def initialize(seed_set, klass, filename, &block)
        @seed_set = seed_set
        @klass = klass
        @filename = filename
        @attributes = []
        @seed_params = %i(id)
        self.instance_eval(&block)
      end

      def has_attributes(*new_attributes)
        @attributes += new_attributes
      end

      def has_seed_params(*params)
        @seed_params = params
      end

      def write_to_folder(folder)
        return unless attributes.any?
        CSV.open(File.join(folder, "#{self.filename}.csv"), 'w') do |csv|
          csv << self.attributes
          self.items.each do |item|
            data = self.attributes.collect { |attribute| self.value_for_attribute(item, attribute) }
            csv << data
          end
        end
      end

      def value_for_attribute(item, attribute)
        value = item.send(attribute)
        if value.is_a?(ActiveRecord::Base)
          value = self.seed_set.seed_param_for_record(value)
        end
        value
      end

      def items
        @klass.all
      end

      def seed_identifier_for_record(record)
        self.seed_params.collect { |param| self.value_for_attribute(record, param) }.join("::")
      end
    end
  end
end