# Buffet Changelog

## master (unreleased)

* `prepare_script` and `worker_command` commands will passed `BUFFET_MASTER`
  and `BUFFET_PROJECT` environment variables
* `prepare_script` will no longer receive master and project name from the
  command line
* Drop support for RSpec 1
* Rename `prepare_script` option to `prepare_command`

## 1.4.0

* Fix `--version` flag crash
* Allow display of progress dots to be disabled via configuration file's
  `display_progress` option

## 1.3.0

* Add spurious failure detection
* Show spec failures immediately after summary statistics

## 1.2.9

* Bias master to distribute longer specs (by number of lines) first to
  improve slave utilization

## 1.2.8

* Add `--version` flag
* Fix bug where specs where being run more than once
* Add support for `ci_reporter` statistics

## 1.2.7

* Prevent workers from clearing shared examples after each run
* Exit with non-zero status when no examples are run
* Show order specs ran in on slaves with failures (to help with debugging
  spurious failures)

## 1.2.4

* Add MIT license to gemspec

## 1.2.3

* Append failed shared example info to location, not message
* Raise error when external shell commands fail
* Add `allowed_prepare_slave_failures` setting to make Buffet more resilient
  to down nodes before a test run

## 1.2.2

* Return information about example groups for shared example failures

## 1.2.1

* Fix Ruby 1.9 compatibility issues in command-line option parsing
* Fix Ruby 1.9 compatibility when loading RSpec formatters in Buffet workers

## 1.2

* Allow worker command to be customized via Buffet configuration file
* Allow custom log file to be specified via the `-l`/`--log` option

## 1.1.2

* Fix bug where RSpec 2 pending specs were recorded as failures

## 1.1.1

* Fix bug where Buffet would crash when running with RSpec 2

## 1.1

* Add `--config` flag allowing users to specify custom configuration other
  than the default `buffet.yml`
* Don't wait for all slaves to run migrations before beginning tests
* Display statistics for each Buffet slave after run
* Allowing specifying the project workspace name using the `--project` flag
* Add support for specifying an `rsync` exclude filter
* Delete excluded project files from worker project space
* Return non-zero exit status on test failure
