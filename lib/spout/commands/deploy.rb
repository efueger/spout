# frozen_string_literal: true

require "net/http"
require "io/console"

require "spout/helpers/subject_loader"
require "spout/helpers/config_reader"
require "spout/helpers/quietly"
require "spout/helpers/send_file"
require "spout/helpers/semantic"
require "spout/helpers/json_request"
require "spout/helpers/send_json"

# - **User Authorization**
#   - User authenticates via token, the user must be a dataset editor
# - **Version Check**
#   - "v#{VERSION}" matches HEAD git tag annotation
#   - `CHANGELOG.md` top line should include version, ex: `## 0.1.0`
#   - Git Repo should have zero uncommitted changes
# - **Tests Pass**
#   - `spout t` passes for RC and FINAL versions (Include .rc, does not include .beta)
#   - `spout c` passes for RC and FINAL versions (Include .rc, does not include .beta)
# - **Graph Generation**
#   - `spout g` is run
#   - Graphs are pushed to server
# - **Dataset Uploads**
#   - Dataset CSV data dictionary is generated (variables, domains, forms)
#   - Dataset and data dictionary CSVs uploaded to files section of dataset
# - **Server-Side Updates**
#   - Server checks out branch of specified tag
#   - Server runs `load_data_dictionary!` for specified dataset slug
#   - Server refreshes dataset folder to reflect new dataset and data dictionaries

class DeployError < StandardError
end

module Spout
  module Commands
    # Deploys a data dictionary and associated dataset to the server.
    class Deploy
      include Spout::Helpers::Quietly

      INDENT_LENGTH = 23
      INDENT = " " * INDENT_LENGTH

      attr_accessor :token, :version, :slug, :url, :config, :environment, :webserver_name, :subjects

      def initialize(argv, version)
        argv.shift # Remove "download" command from argv list
        @environment = argv.shift
        @version = version
        @skip_checks = !(argv.delete("--skip-checks").nil? && argv.delete("--no-checks").nil?)

        @skip_tests = !(argv.delete("--skip-tests").nil? && argv.delete("--no-tests").nil?)
        @skip_coverage = !(argv.delete("--skip-coverage").nil? && argv.delete("--no-coverage").nil?)

        @skip_variables = !(argv.delete("--skip-variables").nil? && argv.delete("--no-variables").nil?)
        @skip_dataset = !(argv.delete("--skip-dataset").nil? && argv.delete("--no-dataset").nil?)
        @skip_dictionary = !(argv.delete("--skip-dictionary").nil? && argv.delete("--no-dictionary").nil?)
        @skip_documentation = !(argv.delete("--skip-documentation").nil? && argv.delete("--no-documentation").nil?)
        @clean = !(argv.delete("--no-resume").nil? && argv.delete("--clean").nil?)
        @skip_server_scripts = !(argv.delete("--skip-server-scripts").nil? && argv.delete("--no-server-scripts").nil?)
        @archive_only = !(argv.delete("--archive-only").nil?)

        token_arg = argv.find { |arg| /^--token=/ =~ arg }
        argv.delete(token_arg)
        @token = token_arg.gsub(/^--token=/, "") if token_arg

        rows_arg = argv.find { |arg| /^--rows=(\d*)/ =~ arg }
        argv.delete(rows_arg)
        @number_of_rows = rows_arg.gsub(/--rows=/, "").to_i if rows_arg

        @argv = argv

        @created_folders = []

        begin
          run_all
        rescue Interrupt
          puts "\nINTERRUPTED".red
        end
      end

      def run_all
        config_file_load
        version_check
        test_check
        coverage_check
        user_authorization
        upload_variables
        dataset_uploads
        data_dictionary_uploads
        markdown_uploads
        trigger_server_updates
        set_default_dataset_version
      rescue DeployError
        # Nothing on Deploy Error
      end

      def config_file_load
        print "   `.spout.yml` Check: "
        @config = Spout::Helpers::ConfigReader.new

        @slug = @config.slug

        if @slug == ""
          message = "#{INDENT}Please specify a dataset slug in your `.spout.yml` file!".red + " Ex:\n---\nslug: mydataset\n".gray
          failure(message)
        end

        if @config.webservers.empty?
          message = "#{INDENT}Please specify a webserver in your `.spout.yml` file!".red + " Ex:\n---\nwebservers:\n  - name: production\n    url: https://sleepdata.org\n  - name: staging\n    url: https://staging.sleepdata.org\n".gray
          failure(message)
        end

        matching_webservers = @config.webservers.select { |wh| /^#{@environment}/i =~ wh["name"].to_s.downcase }
        if matching_webservers.count == 0
          message = "#{INDENT}0 webservers match '#{@environment}'.".red + " The following webservers exist in your `.spout.yml` file:\n" + "#{INDENT}#{@config.webservers.collect{|wh| wh['name'].to_s.downcase}.join(', ')}".white
          failure(message)
        elsif matching_webservers.count > 1
          message = "#{INDENT}#{matching_webservers.count} webservers match '#{@environment}'.".red + " Did you mean one of the following?\n" + "#{INDENT}#{matching_webservers.collect{|wh| wh['name'].to_s.downcase}.join(', ')}".white
          failure(message)
        end

        @webserver_name = matching_webservers.first["name"].to_s.strip rescue @webserver_name = ""
        @url = URI.parse(matching_webservers.first["url"].to_s.strip) rescue @url = nil

        if @url.to_s == ""
          message = "#{INDENT}Invalid URL format for #{matching_webservers.first['name'].to_s.strip.downcase} webserver: ".red + "'#{matching_webservers.first['url'].to_s.strip}'".white
          failure(message)
        end

        puts "PASS".green
        puts "        Target Server: " + "#{@url}".white
        puts "       Target Dataset: " + "#{@slug}".white
      end

      # - **Version Check**
      #   - Git Repo should have zero uncommitted changes
      #   - `CHANGELOG.md` top line should include version, ex: `## 0.1.0`
      #   - "v#{VERSION}" matches HEAD git tag annotation
      def version_check
        if @skip_checks
          puts "        Version Check: " + "SKIP".blue
          return
        end

        stdout = quietly do
          `git status --porcelain`
        end

        print "     Git Status Check: "
        if stdout.to_s.strip == ""
          puts "PASS".green + " " + "nothing to commit, working directory clean".white
        else
          message = "#{INDENT}working directory contains uncomitted changes\n#{INDENT}use `".red + "--skip-checks".white + "` to ignore this step".red
          failure message
        end

        changelog = File.open("CHANGELOG.md", &:readline).strip rescue changelog = ""
        if changelog.match(/^## #{@version.split('.')[0..2].join('.')}/)
          puts "         CHANGELOG.md: " + "PASS".green + " " + changelog.white
        else
          print "         CHANGELOG.md: "
          message = "#{INDENT}Expected: ".red + "## #{@version}".white +
                  "\n#{INDENT}  Actual: ".red + changelog.white
          failure message
        end

        stdout = quietly do
          `git describe --exact-match HEAD --tags`
        end

        print "        Version Check: "
        tag = stdout.to_s.strip
        if "v#{@version}" != tag
          message = "#{INDENT}Version specified in `VERSION` file ".red + "'v#{@version}'".white + " does not match git tag on HEAD commit ".red + "'#{tag}'".white
          failure message
        else
          puts "PASS".green + " VERSION " + "'v#{@version}'".white + " matches git tag " + "'#{tag}'".white
        end
      end

      def test_check
        if @skip_tests
          puts "          Spout Tests: " + "SKIP".blue
          return
        end

        print "          Spout Tests: "

        stdout = quietly do
          `spout t`
        end

        if stdout.match(/[^\d]0 failures, 0 errors,/)
          puts "PASS".green
        else
          message = "#{INDENT}spout t".white + " had errors or failures".red + "\n#{INDENT}Please fix all errors and failures and then run spout deploy again."
          failure message
        end
      end

      def coverage_check
        if @skip_coverage
          puts "     Dataset Coverage: " + "SKIP".blue
          return
        end

        puts "     Dataset Coverage: " + "NOT IMPLEMENTED".yellow
      end

      def user_authorization
        puts  "  Get your token here: " + "#{@url}/token".blue.bg_gray.underline
        print "     Enter your token: "
        @token = STDIN.noecho(&:gets).chomp if @token.to_s.strip == ""
        (json, _status) = Spout::Helpers::JsonRequest.get("#{@url}/datasets/#{@slug}/a/#{@token}/editor.json")
        if json.is_a?(Hash) && json["editor"]
          puts "AUTHORIZED".green
        else
          puts "UNAUTHORIZED".red
          puts "#{INDENT}You are not set as an editor on the #{@slug} dataset or you mistyped your token."
          raise DeployError
        end
      end

      def upload_variables
        if @skip_variables
          puts "     Upload Variables: " + "SKIP".blue
          return
        end
        load_subjects_from_csvs
        graph_generation
      end

      def load_subjects_from_csvs
        @dictionary_root = Dir.pwd
        @variable_files = Dir.glob(File.join(@dictionary_root, "variables", "**", "*.json"))
        @subject_loader = Spout::Helpers::SubjectLoader.new(@variable_files, [], @version, @number_of_rows, @config.visit)
        @subject_loader.load_subjects_from_csvs!
        @subjects = @subject_loader.subjects
      end

      def graph_generation
        # failure ""
        require "spout/commands/graphs"
        @argv << "--clean" if @clean
        Spout::Commands::Graphs.new(@argv, @version, true, @url, @slug, @token, @webserver_name, @subjects)
        puts "\r     Upload Variables: " + "DONE          ".green
      end

      def dataset_uploads
        if @skip_dataset
          puts "      Dataset Uploads: " + "SKIP".blue
          return
        end

        available_folders = (Dir.exist?("csvs") ? Dir.entries("csvs").select { |e| File.directory? File.join("csvs", e) }.reject { |e| [".", ".."].include?(e) }.sort : [])
        semantic = Spout::Helpers::Semantic.new(@version, available_folders)
        csv_directory = semantic.selected_folder
        csv_files = Dir.glob("csvs/#{csv_directory}/**/*.csv")

        csv_files.each_with_index do |csv_file, index|
          print "\r      Dataset Uploads: " + "#{index + 1} of #{csv_files.count}".green
          folder = csv_file.gsub(%r{^csvs/#{csv_directory}}, "").gsub(/#{File.basename(csv_file)}$/, "")
          folder = folder.gsub(%r{/$}, "")
          @created_folders << "datasets#{folder}"
          @created_folders << "datasets/archive"
          @created_folders << "datasets/archive/#{@version}#{folder}"
          upload_file(csv_file, "datasets#{folder}") unless @archive_only
          upload_file(csv_file, "datasets/archive/#{@version}#{folder}")
        end
        puts "\r      Dataset Uploads: " + "DONE          ".green
      end

      def data_dictionary_uploads
        if @skip_dictionary
          puts "   Dictionary Uploads: " + "SKIP".blue
          return
        end

        print "   Dictionary Uploads:"

        require "spout/commands/exporter"
        Spout::Commands::Exporter.new(@version, ["--quiet"])

        csv_files = Dir.glob("exports/#{@version}/*.csv")
        csv_files.each_with_index do |csv_file, index|
          print "\r   Dictionary Uploads: " + "#{index + 1} of #{csv_files.count}".green
          @created_folders << "datasets"
          @created_folders << "datasets/archive"
          @created_folders << "datasets/archive/#{@version}"
          upload_file(csv_file, "datasets") unless @archive_only
          upload_file(csv_file, "datasets/archive/#{@version}")
        end
        puts "\r   Dictionary Uploads: " + "DONE          ".green
      end

      def markdown_uploads
        if @skip_documentation
          puts "Documentation Uploads: " + "SKIP".blue
          return
        end

        print "Documentation Uploads:"
        markdown_files = Dir.glob(%w(CHANGELOG.md KNOWNISSUES.md))
        markdown_files.each_with_index do |markdown_file, index|
          print "\rDocumentation Uploads: " + "#{index + 1} of #{markdown_files.count}".green
          @created_folders << "datasets"
          @created_folders << "datasets/archive"
          @created_folders << "datasets/archive/#{@version}"
          upload_file(markdown_file, "datasets") unless @archive_only
          upload_file(markdown_file, "datasets/archive/#{@version}")
        end
        puts "\rDocumentation Uploads: " + "DONE          ".green
      end

      def trigger_server_updates
        if @skip_server_scripts
          puts "Launch Server Scripts: " + "SKIP".blue
          return
        end

        print "Launch Server Scripts: "
        params = { auth_token: @token, dataset: @slug, version: @version, folders: @created_folders.compact.uniq }
        (json, _status) = Spout::Helpers::SendJson.post("#{@url}/api/v1/dictionary/refresh.json", params)
        if json.is_a?(Hash) && json["refresh"] == "success"
          puts "DONE".green
        else
          puts "FAIL".red
          raise DeployError
        end
      end

      def set_default_dataset_version
        if @archive_only
          puts "  Set Default Version: " + "SKIP".blue
          return
        end
        print "  Set Default Version: "
        params = { auth_token: @token, dataset: @slug, version: @version }
        (json, _status) = Spout::Helpers::SendJson.post(
          "#{@url}/api/v1/dictionary/update_default_version.json", params
        )
        if json.is_a?(Hash) && json["version_update"] == "success"
          puts @version.to_s.green
        else
          failure("#{INDENT}Unable to set default version\n#{INDENT}to " + @version.to_s.white + " for " + @slug.to_s.white + " dataset.")
        end
      end

      def failure(message)
        puts "FAIL".red
        puts message
        raise DeployError
      end

      def upload_file(file, folder)
        Spout::Helpers::SendFile.post("#{@url}/api/v1/dictionary/upload_file.json", file, @version, @token, @slug, folder)
      end
    end
  end
end
