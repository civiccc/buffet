# Buffet

## How to install

`gem install buffet-gem --pre`

`buffet`

Optional: Create a file called `db_setup`, to be run every time Buffet runs, and put it in `[your repo]/bin`. We use this script to reset the testing databases. Be sure that this script also rests the databases on the hosts as well.

### How to use

The CLI is a little more powerful than the web interface. Currently working on making them equal.

`buffet --help` to see options. `buffet` starts testing. For continuous integration, you may be interested in `buffet --watch`. 

### Web interface:

`buffet-web`. Then navigate to `localhost:9292/test`.

After you've started the server, try `curl 'localhost:9292/start-buffet-server/[BRANCH]'`

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
