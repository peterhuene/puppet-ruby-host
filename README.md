Puppet Ruby Host
================

This is a prototype implementation of a host process for Puppet functions and resource types implemented in Ruby.

The Puppet ruby host is responsible for loading and describing Puppet types and functions for requested Puppet
environments.  The host can also be used to dispatch calls to Puppet functions implemented in Ruby.

Supported Features
------------------

* Describing Puppet 4.x functions
* Dispatching Puppet 4.x functions (not yet implemented: access to scope, catalog, or calling other Puppet functions;
***note: Ruby functions may yield to Puppet blocks***).
* Describing Puppet 3.x+ resource types.

***Note: the resource type service supports environment isolation in that Puppet resource types may differ their
definitions between environments.  However, resource types may not load different versions of the same gem as a single
Ruby VM is being used.*** 

***Note: as the host does not use Puppet directly, only the minimum Puppet API is implemented: functions
and resource types that make use of parts of Puppet (especially those relying on private implementation) may not yet be
supported.***

Installation
------------

Use `bundle install` to install the `puppet-ruby-host` bundle.

Running The Host
----------------

To run the host, use the `puppet-ruby-host` script in the `bin/` directory:

```
$ bundle exec bin/puppet-ruby-host function type --listen unix:/tmp/puppet-ruby-host.socket
```

The `function` argument loads the Puppet function service responsible for describing and dispatching Puppet functions
written in Ruby.

The `type` argument loads the Puppet type service responsible for describing Puppet resource types implemented in Ruby.

The `listen` option tells the host to listen on a UNIX domain socket rather than a network address.

Using The Host
--------------

To use the host with the prototype native Puppet compiler:

```
$ puppetcpp compile --ruby-host unix:/tmp/puppet-ruby-host.socket --trace
```

The `ruby-host` option instructs the native compiler to connect to the host
to support Puppet resource types and functions written in Ruby.

The `trace` option will display backtraces for errors with Puppet and Ruby frames.

Stopping The Host
-----------------

Use `Ctrl-C` to stop the Ruby host process.

Generating Protocol Files
-------------------------

If the service definitions change in the `protocols` directory, use the following command to recreate the source files:

```
$ rake generate
```
