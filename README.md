# Buffet

Buffet is a test distribution framework for Ruby applications. It distributes
your tests across multiple worker machines and runs them in parallel, which
significantly speeds up the testing cycle.

## Installation

Install: `gem install buffet-gem`

## Usage

Run `buffet` from the command line at the top level of your application.

Buffet expects to find a `buffet.yml` file in the same directory which tells it
about the project being tested and what machines it should run on.

## Details

If you have database or other set-up that need to perform before every test you
can create a `bin/before-buffet-run` script which makes the necessary
preparations.
