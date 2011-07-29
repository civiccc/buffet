# Buffet

## How to install

We aim to make this as short as possible.

1. Copy the sample settings file to settings.yml and change it.

2. Create a file called `db_setup`, and put it in `[your repo]/bin`. This file should nuke and recreate the testing databases. Currently, it also sshes into the other hosts and does the same thing. That behaviour is a little confusing. It should probably change. This step is currently optional; if a db_setup script doesn't exist, nothing will happen. 


### How to use

The CLI is a little more powerful than the web interface. Currently working on making them equal.



`bundle exec lib/cli.rb --help` to see options. `bundle exec lib/cli.rb` is basic functionality. Also, you may be interested in `bundle exec lib/cli.rb --watch`. 

### Web interface:

`bundle exec rackup`. Then navigate to `localhost:9292/test`.

Or, after you've started the server, try `curl 'localhost:9292/start-buffet-server/BRANCH'`, replacing BRANCH with the correct branch.

## FAQ

`/usr/lib/ruby/1.8/fileutils.rb:243:in `mkdir': Permission denied - /home/(some user) (Errno::EACCES)`

This means that somehow bundle install was called, but is using args found on the master machine, not the host. (Yes, the error is very obscure..)

There are a few ways to solve this problem:
1. You can manually solve this by sshing in and calling bundle install.
2. You can examine the source / bug me to figure out why things are out of order, then fix them.

`unknown database 'buffet_causes'`

You should precede all bundle database commands with `RAILS_ENV=test`.

## TODO

1. Get rid of all TODOs.

2. Feature requests:
* What user did this run on?

3. ???

4. Non-profit

## Looking Forward

1. Use a git wrapper, not inline shell commands.
