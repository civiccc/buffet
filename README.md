Buffet
========

How to install
-------

We aim to make this as short as possible.

1. Create a file called `db_setup`, and put it in `[your repo]/bin`. This file should nuke and recreate the testing databases. Currently, it also sshes into the other hosts and does the same thing. That behaviour is a little confusing. It should probably change. (If you don't create db_setup, the default one will be copied out of Buffet).

2. Make sure that you have the public keys of all hosts in `~/.ssh/known_hosts`. Otherwise you'll get spammed with 'yes to continue' messages, which is annoying.

3. Copy the sample settings file to settings.yml and change it.

4. Each host computer must have a buffet user, and must also have permissions to access the buffet user on each other host.


How to use
-------

`bundle exec rackup`. Then navigate to `localhost:9292/test`.

Or, after you've started the server, try `curl 'localhost:9292/start-buffet-server/BRANCH'`, replacing BRANCH with the correct branch.

FAQ
--------

`/usr/lib/ruby/1.8/fileutils.rb:243:in `mkdir': Permission denied - /home/(some user) (Errno::EACCES)`

This means that somehow bundle install was called, but is using args found on the master machine, not the host. (Yes, the error is very obscure..)

There are a few ways to solve this problem:
1. You can manually solve this by sshing in and calling bundle install.
2. You can examine the source / bug me to figure out why things are out of order, then fix them.

`unknown database 'buffet_causes'`

You should precede all bundle database commands with `RAILS_ENV=test`.

TODO
--------

1. Get rid of all TODOs.

2. Feature requests:
* What user did this run on?
* Regression testing.
* Testing on other repos.

4. ???

5. Non-profit

