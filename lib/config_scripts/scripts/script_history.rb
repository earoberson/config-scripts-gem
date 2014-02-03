module ConfigScripts
  module Scripts
    # This class models a record of a script being run.
    #
    # This uses the +config_scripts+ table to record it histories.
    class ScriptHistory < ActiveRecord::Base
      self.table_name = 'config_scripts'

      # @!attribute name
      # The name of the script, which will be its timestamp.
      # @return [String]

      # This method gets all of the entries that have a timestamp as their name.
      # @return [Relation<ScriptHistory>]
      def self.entries_for_timestamp(timestamp)
        self.where(:name => timestamp)
      end

      # This method determines if we have run a script with a timestamp.
      # @return [Boolean]
      def self.script_was_run?(timestamp)
        self.entries_for_timestamp(timestamp).any?
      end

      # This method records that we have run a script with a timestamp.
      # @return [ScriptHistory]
      def self.record_timestamp(timestamp)
        self.entries_for_timestamp(timestamp).first_or_create
      end

      # This method removes all records that we have run a script with a
      # timestamp.
      # @return [Array<ScriptHistory>]
      def self.remove_timestamp(timestamp)
        self.entries_for_timestamp(timestamp).destroy_all
      end
    end
  end
end