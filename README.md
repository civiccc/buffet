# Buffet

Buffet is a test distribution framework for Ruby applications. It distributes
your tests across multiple worker machines and runs them in parallel, which
significantly speeds up the testing cycle.

## Installation

Install: `gem install minimal-buffet`

## Usage

Run `buffet` from the command line at the top level of your application.

Buffet expects to find a `buffet.yml` file in the same directory which tells it
about the project being tested and what machines it should run on. If you want
to specify a different configuration file, use the --config switch.

## Details

If you have a database or other set-up that needs to be prepared before every
test you can create a `bin/before-buffet-run` script in your application's
folder which makes the necessary preparations (you can customize which file
to use by specifying the prepare_script setting in buffet.yml).
