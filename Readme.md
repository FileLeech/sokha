# Introduction #

`Sokha` is a web frontend for external file-sharing downloaders programmed with [Sinatra](http://www.sinatrarb.com/), a [Ruby](http://www.ruby-lang.org/en/) framework. The currently supported backends are:

| Backend | Support |
|:--------|:--------|
| _plowshare_ | _complete_ |

# Dependencies #

  * [Ruby](http://www.ruby-lang.org/en/) (>= 1.8.6)
  * [Rubygems](http://rubyforge.org/projects/rubygems/) (>= 1.3.6)
  * [Eventmachine](http://rubyeventmachine.com/)
  * [Sinatra](http://www.sinatrarb.com/)

backends:

  * [plowshare](http://code.google.com/p/plowshare/) (>= 0.9.4)

Using `rubygems` you don't need to worry about these dependencies except for the backend, `ruby` and `rubygems`. Make sure the backend is working properly before trying to use it with `sokha`.

## Update your rubygems version ##

You will need `rubygems` >= 1.3.6 to install `sokha`. If you have an older version, update it:

```
$ sudo gem update—system
```

# Install #

## Create the gem ##

First of all, make sure you have `subversion` installed to access the code repository. Then run:

```
$ svn checkout http://sokha.googlecode.com/svn/trunk/ sokha
$ cd sokha
$ gem build sokha.gemspec
```

## Install the gem ##

And install the newly created gem in your user directory:

```
$ gem install --user-install sokha-VERSION.gem
```

Or, if you prefer, make it available to all your users:

```
$ sudo gem install --no-user-install sokha-VERSION.gem
```

# Start the server #

## Find the `sokha` daemon executable ##

If you installed the gem on your home directory, chances are it's to be found in `$HOME/.gem/ruby/1.8/bin`. If you installed it in your system, the path varies (run `gem env` and look for the _EXECUTABLE DIRECTORY_ variable).

Once you found the path to the daemon, add it to your PATH variable (probably modifying `.bashrc`):

```
PATH=$PATH:/path/to/gems/bin
```

## Run the daemon ##

```
$ sokhad start
```

And open your browser: http://localhost:4567 (admin/admin)

## Debugging ##

You run the daemon but the browser won't open the page. Probably something went wrong on the installation, try to run the daemon in the foreground and check the error messages:

```
$ sokhad start -t
```

## Stop the daemon ##

```
$ sokhad stop
```

# Alternative backends #

For now `sokha` only works with `plowshare`, but this support is not  hardcoded, it should be possible to add any other command-line downloader, given that it:

  * is a command-line application with no user interaction needed.
  * is able to return the file URL (not the file itself) and the session's cookies (as a Netscape/mozilla text file) so `sokha` can make the actual file download.
  * (desirable) has meaningful exit codes (so `sokha` can inform the user about what went wrong).

## Contribute ##

The main configuration file should be the only code to modify in _sokha_ to add support for new backends:

http://code.google.com/p/sokha/source/browse/trunk/config.yml

Take a look at the `apps.plowshare` section as an example. Note that `sokha` is still in development and these specifications can change anytime to make room for more backends.

Contributions most welcome.