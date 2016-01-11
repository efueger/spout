require 'test_helpers/sandbox'
require 'test_helpers/capture'

module ApplicationTests
  class OutliersTest < SandboxTest
    include TestHelpers::Capture

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_outliers
      output, error = util_capture do
        Dir.chdir(app_path) { Spout.launch ['outliers', '--console'] }
      end

      index_file = File.read(File.join(app_path, 'coverage', 'outliers.html')) rescue nil
      refute_nil index_file

      assert_match /<title>Spout Outliers<\/title>/, index_file
      assert_match /Generated by <a href=\"https\:\/\/github.com\/sleepepi\/spout\">Spout<\/a> v#{Spout::VERSION::STRING}/, index_file
      assert_match "Generating: outliers.html", output
    end

    def test_no_csvs_for_outliers_report
      output, error = util_capture do
        Dir.chdir(app_path) { Spout.launch(['outliers', '--console']) }
      end

      index_file = File.read(File.join(app_path, 'coverage', 'outliers.html')) rescue nil
      refute_nil index_file

      assert_match /No CSVs found in <code>#{app_path}\/csvs\/1.0.0\/<\/code>/, index_file
      assert_match "Generating: outliers.html", output
    end

    def test_no_csvs_for_outliers_report_with_version_file
      app_file 'VERSION', <<-SCRIPT
        0.1.0.beta5
      SCRIPT

      output, error = util_capture do
        Dir.chdir(app_path) { Spout.launch(['outliers', '--console']) }
      end

      index_file = File.read(File.join(app_path, 'coverage', 'outliers.html')) rescue nil
      refute_nil index_file

      assert_match /No CSVs found in <code>#{app_path}\/csvs\/0.1.0.beta5\/<\/code>/, index_file
      assert_match "Generating: outliers.html", output

      delete_app_file 'VERSION'
    end

    def test_with_csvs
      basic_info
      create_visit_variable_and_domain

      output, error = util_capture do
        Dir.chdir(app_path) { Spout.launch(['outliers', '--console']) }
      end

      assert_match /Parsing files in csvs\/1\.0\.0/, output.uncolorize

      assert_equal [".", "..", "dataset.csv"].sort, Dir.entries(File.join(app_path, 'csvs', '1.0.0')).sort

      index_file = File.read(File.join(app_path, 'coverage', 'outliers.html')) rescue nil
      refute_nil index_file

      refute_match /No CSVs found in <code>#{app_path}\/csvs\/1.0.0\/<\/code>/, index_file

      assert_match /csvs\/1\.0\.0\/dataset\.csv/, index_file
      assert_match "Generating: outliers.html", output

      remove_visit_variable_and_domain
      remove_basic_info
    end
  end
end
