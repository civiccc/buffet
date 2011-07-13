Buffet
========

How to install
-------

We aim to make this as short as possible.

1. Create a file called `db_setup`, and put it in `[your repo]/bin`. This file should nuke and recreate the testing databases. Currently, it also sshes into the other hosts and does the same thing. That behaviour is a little confusing. It should probably change. (If you don't create db_setup, the default one will be copied out of Buffet).

2. Make sure that you have the public keys of all hosts in `~/.ssh/known_hosts`. Otherwise you'll get spammed with 'yes to continue' messages, which is annoying.


How to use
-------

`ruby -rubygems server.rb`. Then navigate to `localhost:4567/test`.

Or, after you've started the server, try `curl 'localhost:4567/start-buffet-server/BRANCH'`, replacing BRANCH with the correct branch.

TODO
--------

1. Get rid of all TODOs.

2. Only run migrations if a hash check doesn't match up.

3. Separate Causes specific files into a .gitignore'd causes/ directory

4. ???

5. Non-profit
