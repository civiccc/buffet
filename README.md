# Buffet

Buffet is a test distribution framework for Ruby. It has been designed to be super simple to set up and use. 

Buffet is in an alpha state. It should work, but there may be some rough patches. Feel free to send questions, or better, pull requests, my way.

![A screenshot of Buffet](http://i.imgur.com/sU247.png)

## Installation

Install: `gem install buffet-gem --pre`

Create a user named 'buffet' on each host; Buffet can take care of the rest. 

## Usage

Run tests: `buffet` for the command line, or `buffet-web`. Your choice. 

## Details

Help: `buffet --help`. 

Settings: `buffet --settings`.

Continuous integration: `buffet --watch`. 

If you have databases that need to be refreshed every time you test: Create a file called `db_setup` to do this, and put it in `[your repo]/bin`. Be sure that this script also rests the databases on the hosts as well.

The CLI currently has more options than the web interface. Working on this.

## FAQ

`/usr/lib/ruby/1.8/fileutils.rb:243:in `mkdir': Permission denied - /home/(some user) (Errno::EACCES)`

This means that somehow bundle install was called, but is using args found on the master machine, not the host. (Yes, the error is very obscure..)

There are a few ways to solve this problem:
1. You can manually solve this by sshing in and calling bundle install.
2. You can examine the source / bug me to figure out why things are out of order, then fix them.

`unknown database 'buffet_causes'`

You should precede all bundle database commands with `RAILS_ENV=test`.

## Looking Forward

1. Use a git wrapper, not inline shell commands.
