module MassiveRecord
  module Wrapper
    class Scanner
      
      attr_accessor :connection, :table_name, :column_family_names, :opened_scanner
      attr_accessor :start_key, :created_at, :limit
      attr_accessor :formatted_column_family_names, :column_family_names
      
      def initialize(connection, table_name, column_family_names, opts = {})
        @connection = connection
        @table_name = table_name
        @column_family_names = column_family_names.collect{|n| n.split(":").first}
        @column_family_names = opts[:columns] unless opts[:columns].nil?
        @formatted_column_family_names = column_family_names.collect{|n| "#{n.split(":").first}:"}
        @start_key = opts[:start_key].to_s
        @created_at = opts[:created_at].to_s
        @limit = opts[:limit] || 10
      end
      
      def open
        if created_at.empty?
          self.opened_scanner = connection.scannerOpen(table_name, start_key, formatted_column_family_names)
        else
          self.opened_scanner = connection.scannerOpenTs(table_name, start_key, formatted_column_family_names, created_at)
        end
      end
      
      def close
        connection.scannerClose(opened_scanner)
      end
      
      def fetch_trows(opts = {})
        connection.scannerGetList(opened_scanner, limit)
      end
      
      def fetch_rows(opts = {})
        populate_rows(fetch_trows(opts))
      end
      
      def populate_rows(results)
        results.collect{|result| populate_row(result)}
      end
      
      def populate_row(result)
        Row.populate_from_trow_result(result, connection, table_name, column_family_names)
      end
      
    end
  end
end