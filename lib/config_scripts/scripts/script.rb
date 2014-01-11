module ConfigScripts
  module Scripts
    class Script
      def self.timestamp
        self.name.index[0,14]
      end

      def self.script_directory
        Rails.root.join('db', 'config_scripts')
      end

      def self.pending_scripts
        paths = Dir.glob(File.join(self.script_directory, '*'))
        paths.collect do |path|
          filename = File.basename(path, ".rb")
          timestamp = filename.index[0, 14]
          ScriptHistory.script_was_run?(timestamp) ? nil : filename
        end.compact
      end

      def self.run_pending_scripts
        self.pending_scripts.each do |filename|
          class_name = filename.classify
          klass = nil
          begin
            klass = class_name.constantize
            klass.new.run(:up)
          rescue ConstantNotFound
            puts "Expected #{filename}"
          end
        end
      end

      def up
        raise "Not supported"
      end

      def down
        raise "Not supported"
      end

      def run(direction)
        ActiveRecord::Base.transaction do
          begin
            self.send(direction)
          rescue => e
            puts "Error running script for #{self.class.name}: #{e.message}"
            puts e.backtrace.first
          end

          case(direction)
          when :up
            ScriptHistory.record_timestamp(self.class.timestamp)
          when :down
            ScriptHistory.remove_timestamp(self.class.timestamp)
          end
          Rails.cache.clear
        end
      end
    end
  end
end