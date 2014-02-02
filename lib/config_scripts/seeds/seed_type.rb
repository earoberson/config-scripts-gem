require 'csv'

module ConfigScripts
  module Seeds
    class SeedType
      attr_reader :seed_set
      attr_reader :klass
      attr_reader :filename
      attr_reader :attributes
      attr_reader :seed_params
      attr_reader :associations

      def initialize(seed_set, klass, filename, &block)
        @seed_set = seed_set
        @klass = klass
        @filename = filename
        @attributes = []
        @seed_params = %i(id)
        self.instance_eval(&block)
        @associations = {}
        @klass.reflect_on_all_associations.each do |association|
          @associations[association.name] = association.klass
        end
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
            data = self.attributes.collect { |attribute| self.write_value_for_attribute(item, attribute) }
            csv << data
          end
        end
      end

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

      def write_value_for_attribute(item, attribute)
        value = item.send(attribute)
        if value.is_a?(ActiveRecord::Base)
          value = self.seed_set.seed_param_for_record(value)
        end
        value
      end

      def read_value_for_attribute(value, attribute)
        if @associations[attribute]
          value = self.seed_set.record_for_seed_identifier(@associations[attribute], value)
        end
        value
      end

      def items
        @klass.all
      end

      def seed_identifier_for_record(record)
        self.seed_params.collect { |param| self.write_value_for_attribute(record, param) }.join("::")
      end

      def record_for_seed_identifier(identifier)
        records = self.klass.scoped
        values = identifier.split("::")
        self.seed_params.each_with_index do |attribute, index|
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