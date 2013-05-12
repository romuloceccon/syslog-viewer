## What's it?

`syslog-viewer` is a `tail`-like command line tool to list events from a MySQL
database populated with `rsyslog`.

## Purpose

When administering anything larger than a small server administrators benefit
greatly from a centralized log solution. In the open source world
syslog/rsyslog is the usual answer, and a database backend like MySQL an
important performance consideration.

Such a setup brings out the problem of presenting the data. There are dozens of
solutions around, both free and commercial, but they either are expensive,
or are difficult to configure, or have a disappointing usability.

And yet, many times, the administrator only wants to have the power of `tail`
again. `syslog-viewer` is just that, with the ability to poll the database
continuously (like `tail`'s `-f`) and filter events by a variety of conditions.

## Installing

`syslog-viewer` is a single Ruby script. To use it make sure your system has
Ruby 1.9 installed, copy `syslog-viewer.rb` anywhere you like and run:

        $ ruby syslog-viewer.rb -h

## Examples

Connect to host `example.org`, using username `joe` and password `123`, and list
last 10 events:

        $ ruby syslog-viewer.rb -c joe:123@example.org

Filter last 100 events with severity _warning_ or greater, and then follow new
events:

        $ ruby syslog-viewer.rb -c joe:123@example.org -s WAR -n 100 -f

Filter events happened between 2013-01-01 0:00:00 and 2013-01-01 2:30:00:

        $ ruby syslog-viewer.rb -c joe:123@example.org -p "2013-01-01 0:00:00,2013-01-01 2:30:00"

Filter the last 20 events happened before 2013-02-04 0:00:00:

        $ ruby syslog-viewer.rb -c joe:123@example.org -p "20,2013-02-04 0:00:00"

It's possible to store common options in `~/.syslog-viewer`: it's a YAML file. The
syntax is exactly the same as in the command line, except for the `connect` option,
whose name changes to `database`:

        example:
          database:
            host: example.org
            port: 3306
            username: joe
            password: '123'
          count: 100
          severity: WARNING

You can then invoke those options by the corresponding label (each label can have
its own group of options):

        $ ruby syslog-viewer.rb -f example

Note: if you specifiy a label in the command line it must be the last option!

## Additional help

Check the [Wiki](https://github.com/romuloceccon/syslog-viewer/wiki).

## License

`syslog-viewer` is released under the
[MIT License](http://www.opensource.org/licenses/MIT).
