require "pathname"
require_relative "./base_test_data"

module RspecTestData
  class SeedsHelper

    def self.for_rails
      self.new(Rails.root / "spec")
    end

    def initialize(spec_path)
      @spec_path = spec_path
    end

    def load(test_data_class_name,**args)
      if test_data_class_name !~ /^RspecTestData::/
        test_data_class_name = "RspecTestData::#{test_data_class_name}"
      end
      parts = test_data_class_name.split(/::/).map(&:underscore)

      path = (@spec_path / parts[1..-1].join("/")).to_s + ".test_data.rb"

      if !File.exist?(path)
        raise "Expected to find test data for #{test_data_class_name} in '#{path}', but that file doesn't exist."
      end

      require_relative path
      test_data_class_name.constantize.new(**args)
    end
  end
end
