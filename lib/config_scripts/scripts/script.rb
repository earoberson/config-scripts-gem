module ConfigScripts
  module Scripts
    # This class is the base class for all of the config scripts that the
    # app will define.
    class Script
      # @!group Config

      # This method gets the directory in which the scripts will be stored.
      #
      # The scripts are stored in the +db/config_scripts+ directory under the app.
      #
      # @return [String]
      def self.script_directory
        Rails.root.join('db', 'config_scripts')
      end

      # @!group Pending Scripts

      # This method gets the scripts that we have not yet run.
      #
      # We will return the filenames, without the extensions.
      #
      # @return [Array<String>]
      def self.pending_scripts
        paths = Dir.glob(File.join(self.script_directory, '*.rb'))
        paths.collect do |path|
          filename = File.basename(path, ".rb")
          timestamp = filename[0, 14]
          ScriptHistory.script_was_run?(timestamp) ? nil : filename
        end.compact
      end

      # This method runs all the scripts that have not yet been run.
      #
      # @return [True]
      def self.run_pending_scripts
        self.pending_scripts.each do |filename|
          path = Rails.root.join('db', 'config_scripts', "#{filename}.rb")
          require path
          timestamp = filename[0,14]
          class_name = filename[15..-1].camelize + 'Config'
          klass = nil
          begin
            klass = class_name.constantize
          rescue NameError
            puts "Aborting: could not find class #{class_name}"
            return
          end
          puts "Running #{filename}"
          success = klass.new(timestamp).run(:up)
        end
        true
      end

      # This method prints out the names of all of the scripts that have not
      # been run.
      def self.list_pending_scripts
        self.pending_scripts.each do |filename|
          puts filename
        end
      end

      # @!group Creating

      # This method creates a new script.
      #
      # @param [String] timestamp
      #   The timestamp that is used to uniquely indentify the script.
      #
      # @return [Script]
      def initialize(timestamp)
        @timestamp = timestamp
      end

      # @!group Running

      # @return [String]
      # The timestamp for this instance of the script.
      attr_accessor :timestamp

      # This method performs the changes for this config script.
      #
      # This implementation raises an exception. Subclasses must define this
      # method.
      #
      # If there are any issues running the script, this method should raise an
      # exception.
      def up
        raise "Not supported"
      end

      # This method rolls back the changes for this config script.
      #
      # This implementation raises an exception. Subclasses must define this
      # method if their scripts can be rolled back.
      #
      # If there are any issues rolling back the script, this method should
      # raise an exception.
      def down
        raise "Not supported"
      end

      # This method runs the script in a given direction.
      #
      # This will use either the +up+ or +down+ method. That method call will be
      # wrapped in a transaction, so if the script raises an exception, all of
      # its changes will be rolled back.
      #
      # If the method runs successfully, this will either record a timestamp
      # or remove a timestamp in the +config_scripts+ table.
      #
      # @param [Symbol] direction
      #   Whether we should run +up+ or +down+.
      def run(direction)
        ActiveRecord::Base.transaction do
          begin
            self.send(direction)
          rescue => e
            puts "Error running script for #{self.class.name}: #{e.message}"
            puts e.backtrace.first
            raise e
          end

          case(direction)
          when :up
            ScriptHistory.record_timestamp(@timestamp)
          when :down
            ScriptHistory.remove_timestamp(@timestamp)
          end
        end
      end
    end
  end
end