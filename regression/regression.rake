require_relative 'regression_tests'

namespace :regression do
  task run: :cleanup do
    RegressionTests.to_a.each do |t|
      puts "Running #{t.name}"
      t.cleanup
      t.run
      t.cleanup
    end
  end

  task :cleanup do
    RegressionTests.each{|t| t.cleanup}
  end
end
