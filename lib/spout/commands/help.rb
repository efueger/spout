# frozen_string_literal: true

module Spout
  module Commands
    class Help
      def initialize(argv)
        send((Spout::COMMANDS[argv[1].to_s.scan(/\w/).first] || :help))
      end

      def help
        puts <<-EOT
Usage: spout COMMAND [ARGS]

The most common spout commands are:
  [n]ew             Create a new Spout dictionary.
                    `spout new <project_name>` creates a new
                    data dictionary in `./<project_name>`
  [t]est            Run tests and show failing tests
  [i]mport          Import a CSV file into the JSON dictionary
  [e]xport [1.0.0]  Export the JSON dictionary to CSV format
  [c]overage        Coverage report, requires dataset CSVs
                    in `<project_name>/csvs/<version>`
  [o]utliers        Outlier report, requires dataset CSVs
                    in `<project_name>/csvs/<version>`
  [g]raphs          Generates JSON graphs for each variable
                    in a dataset and places them
                    in `<project_name>/graphs/<version>/`
  [d]eploy NAME     Push dataset and data dictionary to a
                    webserver specified in `.spout.yml`
  [u]pdate          Update the Spout gem
  [v]ersion         Returns the version of Spout

Commands can be referenced by the first letter:
  Ex: `spout t`, for test

You can also get more in depth help by typing:
  Ex: `spout help deploy`, to list all deploy flags

EOT
      end

      def new_project
        puts <<-EOT
Usage: spout new <project_name> [--skip-gemfile]

Use `--skip-gemfile` to skip installing gems after project creation.

More information here:

https://github.com/sleepepi/spout#generate-a-new-repository-from-an-existing-csv-file

EOT
      end

      def version
        puts <<-EOT
Usage: spout version

Returns version of spout.

EOT
      end

      def test
        puts <<-EOT
Usage: spout test

EOT
      end

      def update
        puts <<-EOT
Usage: spout update

Checks if a newer version of Spout is available.

EOT
      end

      def importer
        puts <<-EOT
Usage: spout import <csv_file>

Optional Flags:
  --domains    Specify to import CSV of domains
  --forms      Specify to import CSV of forms

More information:
https://github.com/sleepepi/spout#generate-a-new-repository-from-an-existing-csv-file
https://github.com/sleepepi/spout#importing-domains-from-an-existing-csv-file
https://github.com/sleepepi/spout#importing-forms-from-an-existing-csv-file
EOT
      end

      def exporter
        puts <<-EOT
Usage: spout export

Exports data dictionary to CSV format.

More information here:

https://github.com/sleepepi/spout#create-a-csv-data-dictionary-from-your-json-repository

EOT
      end

      def coverage_report
        puts <<-EOT
Usage: spout coverage

Generates `coverage/index.html` that can be viewed in browser.

EOT
      end

      def generate_charts_and_tables
        puts <<-EOT
Usage: spout graphs

Optional Flags:
  --clean       Regenerate all graphs (default is to resume
                where command last left off)
  --rows=N      Limit the number of rows read from CSVs to a
                maximum of N rows
  <variable>    Only generate graphs for the specified variable(s)
                Ex: spout graphs age gender

EOT
      end

      def outliers_report
        puts <<-EOT
Usage: spout outliers

Generates `coverage/outliers.html` that can be viewed in browser.

More information here:

https://github.com/sleepepi/spout#identify-outliers-in-your-dataset

EOT
      end

      def deploy
        puts <<-EOT
Usage: spout deploy NAME

NAME is the name of the webserver listed in `.spout.yml` file
Optional Flags:
  --clean               Regenerate all variables (default is to
                        resume where command last left off)
  --rows=N              Limit the number of rows read from CSVs
                        to a maximum of N rows
  <variable>            Only deploy specified variable(s)
                        Ex: spout deploy production age gender
  --skip-checks         Skip git tag and version checks
  --skip-tests          Skip data dictionary tests
  --skip-coverage       Skip dataset coverage check
  --skip-variables      Skip upload of dataset variables
  --skip-dataset        Skip upload of dataset CSVs
  --skip-dictionary     Skip upload of data dictionary
  --skip-documentation  Skip upload of CHANGELOG.md and
                        KNOWNISSUES.md
  --skip-server-scripts Skips server refreshing datasets folder
                        to list newly uploaded files
  --archive-only        Only upload files to the datasets/archive
                        folder and not in the root datasets folder
  --token=TOKEN         Provide token via command-line for
                        automated processes

More information here:

https://github.com/sleepepi/spout#deploy-your-data-dictionary-to-a-staging-or-production-webserver

EOT
      end
    end
  end
end
