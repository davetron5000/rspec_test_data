module RspecTestData
  class Setup
    def initialize(example)
      debug = ->(*) {}

      if example.metadata[:debug_test_data] || ENV["DEBUG_TEST_DATA"] == "true"
        debug = ->(*args) {
          first_message,rest = args[0], args[1..-1]
          puts *([ "[ debug_test_data ] #{args[0]}" ] + args[1..-1])
        }
      end

      use_test_data = example.metadata[:test_data].nil? || example.metadata[:test_data] == true
      if !use_test_data
        debug.("Spec opted out of test_data (#{example.description})")
        return
      end

      test_data_file = example.file_path.gsub(/_spec\.rb$/,".test_data.rb")

      if !File.exists?(test_data_file)
        debug.("Can't find #{test_data_file}, so assuming none to load")
        return
      end

      require test_data_file

      test_data_class_name = "RspecTestData::" + example.file_path.gsub(/^.\/spec\//,"").gsub(/_spec\.rb$/,"").classify
      test_data_class = begin
                          debug.("Loading '#{test_data_class_name}' as the test data class name")
                          test_data_class_name.constantize
                        rescue NameError => ex
                          raise "Expected '#{test_data_file}' to define '#{test_data_class_name}', but it does not: #{ex.message}"
                        end

      example.example_group.let(:test_data_class) { test_data_class }

      if example.example_group.method_defined?(:test_data_override)
        debug.("test_data_override for '#{example.description}'")
        example.example_group.let(:test_data) { test_data_override }
      else
        if example.metadata[:test_data_eager] == true
          test_data = test_data_class.new
          example.example_group.let(:test_data) { test_data }
        else
          example.example_group.let(:test_data) { test_data_class.new }
        end
      end

    end
  end
end
