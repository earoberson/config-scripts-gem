module ConfigScripts
  module Scripts
    class ScriptHistory < ActiveRecord::Base
      self.table_name = 'config_scripts'

      def self.entries_for_timestamp(timestamp)
        self.where(:name => timestamp)
      end

      def self.script_was_run?(timestamp)
        self.entries_for_timestamp(timestamp).any?
      end

      def self.record_timestamp(timestamp)
        self.entries_for_timestamp(timestamp).first_or_create
      end

      def self.remove_timestamp(timestamp)
        self.entries_for_timestamp(timestamp).destroy_all
      end
    end
  end
end