module MassiveRecord
  module ORM
    module Finders
      extend ActiveSupport::Concern

      module ClassMethods
        #
        # Interface for retrieving objects based on key.
        # Has some convenience behaviour like find :first, :last, :all.
        #
        def find(*args)
          raise ArgumentError.new("At least one argument required!") if args.empty?
          raise RecordNotFound.new("Can't find a #{model_name.human} without an ID.") if args.first.nil?

          type = args.shift if args.first.is_a? Symbol
          find_many = type == :all
          expected_result_size = nil
          
          result_from_table = if type
                                table.send(type, *args) # first() / all()
                              else
                                options = args.extract_options!
                                what_to_find = args.first
                                expected_result_size = 1

                                if args.first.kind_of?(Array)
                                  find_many = true
                                elsif args.length > 1
                                  find_many = true
                                  what_to_find = args
                                end

                                expected_result_size = what_to_find.length if what_to_find.is_a? Array
                                table.find(what_to_find, options)
                              end

          # Filter out unexpected IDs (unless type is set (all/first), in that case
          # we have no expectations on the returned rows' ids)
          unless type || result_from_table.blank?
            if find_many
              result_from_table.select! { |result| what_to_find.include? result.id }
            else 
              if result_from_table.id != what_to_find
                result_from_table = nil
              end
            end
          end

          raise RecordNotFound if result_from_table.blank? && type.nil?
          
          if find_many && expected_result_size && expected_result_size != result_from_table.length
            raise RecordNotFound.new("Expected to find #{expected_result_size} records, but found only #{result_from_table.length}")
          end
          
          records = [result_from_table].compact.flatten.collect do |row|
            instantiate(transpose_hbase_columns_to_record_attributes(row))
          end

          find_many ? records : records.first
        end

        def first(*args)
          find(:first, *args)
        end

        def last(*args)
          raise "Sorry, not implemented!"
        end

        def all(*args)
          find(:all, *args)
        end



        private

        def transpose_hbase_columns_to_record_attributes(row)
          attributes = {:id => row.id}
          # Parse the row results to auto populate the instance attributes (see autoload option on column_family)
          unless autoloaded_column_family_names.blank?
            autoloaded_column_family_names.each do |name|
              column_family = column_families.select{|c| c.name == name}.first
              column_family.populate_fields_from_row_columns(row.columns)
              self.attributes_schema = self.attributes_schema.merge(column_family.fields)
            end
            # Clear the array to avoid doing it every time
            autoloaded_column_family_names.clear
          end
          # Parse the schema to populate the instance attributes
          attributes_schema.each do |key, field|
            cell = row.columns[field.unique_name]
            attributes[field.name] = cell.nil? ? nil : cell.deserialize_value
          end
          attributes
        end

        def instantiate(record)
          allocate.tap do |model|
            model.init_with('attributes' => record)
          end
        end
      end
    end
  end
end