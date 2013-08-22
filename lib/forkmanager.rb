# = Parallel::ForkManager -- A simple parallel processing fork manager.
#
# == Copyright (c) 2008 - 2011 Nathan Patwardhan
#
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Ruby itself.
#
# == Author: Nathan Patwardhan <noopy.org@gmail.com>
#
# == Documentation
#
# Nathan Patwardhan <noopy.org@gmail.com>, based on Perl Parallel::ForkManager documentation by Noah Robin <sitz@onastick.net> and dLux <dlux@dlux.hu>.
#
# == Credits (for original Perl implementation):
#
# - dLux <dlux@dlux.hu> (original Perl module)
# - Chuck Hirstius <chirstius@megapathdsl.net> (callback exit status, original Perl example)
# - Grant Hopwood <hopwoodg@valero.com> (win32 port)
# - Mark Southern <mark_southern@merck.com> (bugfix)
# - Ken Clarke <www.perlprogrammer.net>  (data structure retrieval)
#
# == Credits (Ruby port):
#
# - Robert Klemme <shortcutter@googlemail.com>, David A. Black <dblack@rubypal.com>        (general awesomeness)
# - Roger Pack <rogerdpack@gmail.com>          (bugfix, fork semantics in start, doc changes)
# - Mike Stok <mike@stok.ca>          (test cases, percussion, backing vocals)
#
# == Overview
#
# Parallel::ForkManager is used for operations that you would like to do
# in parallel (e.g. downloading a bunch of web content simultaneously) but
# uses fork() to handle parallel processing instead of threads.  If you've
# used fork() before, you're aware that you need to be responsible for
# managing (i.e. cleaning up) the processes that were created as a result.
# Parallel::ForkManager handles this for you such that you start() and
# finish() without having to worry about child processes along
# the way.  Further, Parallel::ForkManager provides useful callbacks
# that you can use when a child starts and/or finishes -- or while you're
# waiting for a child to complete.
#
# The code for a downloader that uses Net::HTTP would look like this:
#
#  require 'rubygems'
#  require 'net/http'
#  require 'forkmanager'
#  
#  my_urls = [
#      'url1',
#      'url2',
#      'urlN'
#  ]
#  
#  max_proc = 30
#  my_timeout = 5
#  
#  pm = Parallel::ForkManager.new(max_proc)
#  
#  my_urls.each {
#      |my_url|
#  
#      pm.start(my_url) and next # blocks until new fork slot is available
#
#      # doing stuff here with my_url will be in a child
#      url = URI.parse(my_url)
#
#      begin
#          http = Net::HTTP.new(url.host, url.port)
#          http.open_timeout = http.read_timeout = my_timeout
#          res = http.get(url.path)
#
#          status = res.code
#          if status.to_i != 200
#              print "Cannot get #{url.path} from #{url.host}!\n"
#              pm.finish(255)
#          else
#              pm.finish(0)
#          end
#      rescue Timeout::Error, Errno::ECONNREFUSED => e
#          print "*** ERROR: #{my_url}: #{e.message}!\n"
#          pm.finish(255)
#      end
#  }
#  
#  pm.wait_all_children
#  
# First you need to instantiate the ForkManager with the "new" constructor. 
# You must specify the maximum number of processes to be created. If you 
# specify 0, then NO fork will be done; this is good for debugging purposes.
#
# Next, use pm.start() to do the fork. pfm returns 0 for the child process, 
# and child pid for the parent process.  The "and next" skips the internal
# loop in the parent process.
#
# - pm.start() dies if the fork fails.
#
# - pm.finish() terminates the child process (assuming a fork was done in the "start").
#
# - You cannot use pm.start() if you are already in the child process. 
#   If you want to manage another set of subprocesses in the child process, 
#   you must instantiate another Parallel::ForkManager object!
#
# == Revision History
#
# - 1.5.1, 2011-03-04: Resolves bug [#29043] wait_one_child failed to retrieve object.  Adds conversion of Object to Hash before serialization to avoid 'singleton can't be dumped' error.  Minor documentation changes for initialize().
# - 1.5.0, 2011-02-25: Implements data structure retrieval as had appeared in Perl Parallel::ForkManager 0.7.6.  Removes support for passing Proc to run_on_* methods; now supports blocks instead.  Documentation updates and code cleanup.
# - 1.2.0, 2010-02-01: Resolves bug [#27748] finish throws an error when used with start(ident).  Adds block support to run_on_start(), run_on_wait(), run_on_finish().
# - 1.1.1, 2010-01-05: Resolves bug with Errno::ECHILD.
# - 1.1.0, 2010-01-01: Resolves bug [#27661] forkmanager doesn't fork!.  Adds block support to start() w/doc changes for same.
# - 1.0.1, 2009-10-24: Resolves bug [#27328] dies with max procs 1.
# - 1.0.0, 2008-11-03: Initial release.
#
# == Bugs and Limitations
#
# Parallel::ForkManager is a Ruby port of Perl Parallel::ForkManager
# 0.7.9.  It was originally ported from Perl Parallel::ForkManager 0.7.5
# but was recently updated to integrate features implemented in Perl
# Parallel::ForkManager versions 0.7.6 - 0.7.9.  Bug reports and feature
# requests are always welcome.
#
# Do not use Parallel::ForkManager in an environment where other child
# processes can affect the run of the main program, so using this module
# is not recommended in an environment where fork() / wait() is already used.
#
# If you want to use more than one copy of the Parallel::ForkManager then
# you have to make sure that all children processes are terminated -- before you
# use the second object in the main program.
#
# You are free to use a new copy of Parallel::ForkManager in the child
# processes, although I don't think it makes sense.
#
# == Examples
#
# === Callbacks
#
# Example of a program using callbacks to get child exit codes:
#
#  require 'rubygems'
#  require 'forkmanager'
#  
#  max_procs = 5
#  names = %w{ Fred Jim Lily Steve Jessica Bob Dave Christine Rico Sara }
#
#  pm = Parallel::ForkManager.new(max_procs)
#
#  # Setup a callback for when a child finishes up so we can get it's exit code
#  pm.run_on_finish {
#      |pid,exit_code,ident|
#      print "** #{ident} just got out of the pool with PID #{pid} and exit code: #{exit_code}\n"
#  }
#
#  pm.run_on_start {
#      |pid,ident|
#      print "** #{ident} started, pid: #{pid}\n"
#  }
#
#  pm.run_on_wait(0.5) {
#      print "** Have to wait for one children ...\n"
#  }
#
#  names.each_index {
#      |child|
#      pid = pm.start(names[child]) and next
#
#      # This code is the child process
#      print "This is #{names[child]}, Child number #{child}\n"
#      sleep ( 2 * child )
#      print "#{names[child]}, Child #{child} is about to get out...\n"
#      sleep 1
#      pm.finish(child) # pass an exit code to finish
#  }
#
#  print "Waiting for Children...\n"
#  pm.wait_all_children
#  print "Everybody is out of the pool!\n"
#
# === Data structure retrieval
#
# In this simple example, each child sends back a string.
#
#  require 'rubygems'
#  require 'forkmanager'
#  
#  max_procs = 2
#  persons = %w{Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry}
#
#  pm = Parallel::ForkManager.new(max_procs, {'tempdir' => '/tmp'}, 0)
#
#  # data structure retrieval and handling
#  pm.run_on_finish { # called BEFORE the first call to start()
#      |pid,exit_code,ident,exit_signal,core_dump,data_structure|
#
#      # retrieve data structure from child
#      if defined? data_structure # children are not forced to send anything
#          str = data_structure # child passed a string
#          print "#{str}\n"
#      else  # problems occuring during storage or retrieval will throw a warning
#          print "No message received from child process #{pid}!\n"
#      end
#  }
#
#  # prep random statement components
#  foods = ['chocolate', 'ice cream', 'peanut butter', 'pickles', 'pizza', 'bacon', 'pancakes', 'spaghetti', 'cookies']
#  preferences = ['loves', 'can\'t stand', 'always wants more', 'will walk 100 miles for', 'only eats', 'would starve rather than eat']
#  
#  # run the parallel processes
#  persons.each {
#      |person|
#      pm.start() and next
#
#      # generate a random statement about food preferences
#      pref_idx = preferences.index(preferences.sort_by{ rand }[0])
#      food_idx = foods.index(foods.sort_by{ rand }[0])
#      statement = "#{person} #{preferences[pref_idx]} #{foods[food_idx]}"
#  
#      # send it back to the parent process
#      pm.finish(0, statement)
#  }
#
#  pm.wait_all_children
#
#
# A second data structure retrieval example demonstrates how children
# decide whether or not to send anything back, what to send and how the
# parent should process whatever is retrieved.
#
#  require 'rubygems'
#  require 'forkmanager'
#  
#   max_procs = 20
#   persons = %w{Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry}
# 
#   pm = Parallel::ForkManager.new(max_procs, {'tempdir' => '/tmp'}, 0)
# 
#   # data structure retrieval and handling
#   retrieved_responses = {} # for collecting responses
# 
#   # data structure retrieval and handlin
#   pm.run_on_finish { # called BEFORE the first call to start()
#       |pid,exit_code,ident,exit_signal,core_dump,data_structure|
# 
#       # see what child sent us, if anything
#       if defined? data_structure and !data_structure.empty? # test rather than assume child sent anything
#           dsr = data_structure # child passed a string
#           print "#{ident} returned a #{dsr}.\n\n"
#           p dsr
# 
#           retrieved_responses[ident] = dsr
#       else
#           print "#{ident} did not send anything.\n\n"
#       end
#   }
# 
#   # generate a list of instructions
#   instructions = [  # a unique identifier and what the child process should send
#       {'name' => '%ENV keys as a string', 'send' => 'keys'},
#       {'name' => 'Send Nothing'},  # not instructing the child to send anything back to the parent
#       {'name' => 'Childs %ENV', 'send' => 'all'},
#       {'name' => 'Child chooses randomly', 'send' => 'random'},
#       {'name' => 'Invalid send instructions', 'send' => 'Na Na Nana Na'},
#       {'name' => 'ENV values in an array', 'send' => 'values'},
#   ]
# 
#   # prep random statement components
#   foods = ['chocolate', 'ice cream', 'peanut butter', 'pickles', 'pizza', 'bacon', 'pancakes', 'spaghetti', 'cookies']
#   preferences = ['loves', 'can\'t stand', 'always wants more', 'will walk 100 miles for', 'only eats', 'would starve rather than eat']
#   
#   # run the parallel processes
#   instructions.each {
#       |instruction|
#       pm.start(instruction['name']) and next # this time we are using an explicit, unique child process identifier
# 
#       if !instruction.has_key?("send")
#           print "MT name #{instruction['name']}\n"
#           pm.finish(0)
#       end
# 
#       if instruction['send'] == 'keys'
#           pm.finish(0, ENV.keys())
#       elsif instruction['send'] == 'values'
#           pm.finish(0, ENV.values())
#       elsif instruction['send'] == 'all'
#           pm.finish(0, ENV)
#       elsif instruction['send'] == 'random'
#           str = "I'm just a string."
#           arr = %w{I am an array};
#           hsh = {'type' => 'associative array', 'synonym' => 'hash', 'cool' => 'very :)'}
#           choices = %w{str arr hsh}
#           return_choice = choices.index(choices.sort_by{ rand }[0])
# 
#           if choices[return_choice] == 'str'
#               pm.finish(0, str)
#           elsif choices[return_choice] == 'arr'
#               pm.finish(0, arr)
#           elsif choices[return_choice] == 'hsh'
#               pm.finish(0, hsh)
#           end
#       else
#           pm.finish(0, "Invalid instructions: #{instruction['send']}\n")
#       end
#   }
# 
#   pm.wait_all_children
# 
#   # post fork processing of returned data structures
#   retrieved_responses.keys.sort.each {
#       |response|
#       print "Post processing \"#{response}\"...\n"
#   }
#

require 'tmpdir'
include Process

module Parallel

class ForkManager
    VERSION = '1.5.1' # $Revision: 42 $

# new(max_procs, [params, debug])
#
# Instantiate a Parallel::ForkManager object. You must
# specify the maximum number of children to fork off. If you specify 0 (zero),
# then no children will be forked and debugging output will be enabled.
#
# The optional second parameter, params, is only used if you want to customize
# the behavior that children will use to send back some data (see Retrieving
# Data Structures below) to the parent.  The following values are currently
# accepted for params (and their meanings):
# - params['tempdir'] represents the location of the temporary directory where serialized data structures will be stored.
# - params['serialize_as'] represents how the data will be serialized # (NOTE: currently unimplemented in Parallel::ForkManager 1.5.1).
#
# If params has not been provided, the following values are set:
# - @tempdir is set to Dir.tmpdir() (likely defaults to /tmp).
# - @serialize_as is set to 'marshal'.
#
# NOTE NOTE NOTE: If you set tempdir to a directory that doe not exist,
# Parallel::ForkManager will <em>not</em> create this directory for you
# and new() will exit!
#
# The optional third parameter, debug, is used to set debugging behavior
# for Parallel::ForkManager.  Default value for debug is 0 (off).
#

    def initialize(max_procs = 0, params = {}, debug = 0)
        @max_procs = max_procs
        @debug = debug # Set debug to 1 for debugging messages.
        @params = params
        @processes = {}
        @do_on_finish = {}
        @in_child = false
        @has_block = false
        @on_wait_period = nil
	@parent_pid = $$
        @tempdir = @params['tempdir'] || Dir.tmpdir()
        @do_serialize = 0
        @serialize_as = nil
        @data_structure = nil

        # Make sure that @tempdir has a trailing slash.
        @tempdir <<= (@tempdir[(@tempdir.length-1)..-1] != "/") ? "/" : ""
        
        # Always provide debug information if our max processes are zero!        
        if @max_procs.zero?
            print "Zero processes have been specified so we will not fork and will proceed in debug mode!\n"
            @debug = 1
        end
        
        if @debug == 1
            print "in initialize #{max_procs}!\n"
            print "Will use tempdir #{@tempdir}\n"
        end
        
        if @params.keys.length > 0
            if !defined? params['tempdir']
                print "params missing required argument: tempdir!"
                exit 1
            end
            
            if ! File.directory? @params['tempdir']
                print "Temporary directory #{@params['tempdir']} doesn't exist or is not a directory.\n"
                exit 1
            end
            @tempdir = @params['tempdir']
            @do_serialize = 1

            #
            # As of version 2.0, Marshal is the only way to serialize data that
            # we support.  YAML and others will likely be supported in later
            # versions.
            #
            if params.has_key? "serialize_as" or params.has_key? "serialize_type"
                @serialize_as = (params.has_key? "serialize_as") ? params['serialize_as'] : params['serialize_type']
            else
                @serialize_as = 'marshal'
            end
        else
            @serialize_as = 'marshal'
        end
    end

#
# start("string") -- "string" identification is optional.
#
# start("string") "puts the fork in Parallel::ForkManager" -- as start() does
# the fork().
#
# start("string") takes an optional "string" argument to
# use as a process identifier.  It is used by 
# the "run_on_finish" callback for identifying the finished
# process.  See run_on_finish() for more information.  For example:
#
#   my_ident = "webwacker-1.0"
#   pm.start(my_ident)
#
# start("string") { block } takes an optional block parameter
# that tells the ForkManager to follow Ruby fork() semantics for blocks.
# For example:
#
#   my_ident = "webwacker-1.0"
#   pm.start(my_ident) {
#       print "As easy as "
#       [1,2,3].each {
#           |i|
#           print i, "... "
#       }
#   }
#
# start("string", arg1, arg2, ... , argN) { block } requires a block parameter
# that tells the ForkManager to follow Ruby fork() semantics for blocks.  Like
# start("string"), "string" is an optional argument to use as a process
# identifier and is used by the "run_on_finish" callback for identifying
# the finished process.  For example:
#
#   my_ident = "webwacker-1.0"
#   pm.start(my_ident, 1, 2, 3) {
#       |*my_args|
#       unless my_args.empty?
#           print "As easy as "
#           my_args.each {
#               |i|
#               print i, "... "
#           }
#       end
#   }
#
# <em>NOTE NOTE NOTE: when you use start("string") with an optional block
# parameter, the code in your block *must* explicitly exit non-zero if you are
# using callbacks with the ForkManager (e.g. run_on_finish).</em>  This is
# because fork(), when run with a block parameter, terminates the subprocess
# with a status of 0 by default.  If your block fails to exit non-zero,
# *all* of your exit_code(s) will be zero regardless of any value you might
# have passed to finish(...).
#
# To accommodate this behavior of fork and blocks, you can do
# something like the following:
#
#   my_urls = [ ... some list of urls here ... ]
#   my_ident = "webwacker-1.0"
#
#   my_urls.each {
#       |my_url|
#       pm.start(my_ident) {
#           my_status = get_some_url(my_url)
#           if my_status.to_i == 200
#               exit 0
#           else
#               exit 255
#       }
#   }
#
#   ... etc ...
#
# Return: PID of child process if in parent, or 0 if in the
# child process.

    def start(identification=nil, *args, &run_block)
        if @in_child
            raise "Cannot start another process while you are in the child process"
        end

        while(@processes.length() >= @max_procs)
            on_wait()
            arg = (defined? @on_wait_period and !@on_wait_period.nil?) ? Process::WNOHANG : nil
            wait_one_child(arg)
        end

        wait_children()

        if @max_procs
            if(block_given?)
                raise "start(...) wrong number of args\n" if run_block.arity >= 0 && args.size != run_block.arity
                @has_block = true
                pid = (! args.empty?) ? fork { run_block.call(*args); } : fork { run_block.call(); }
            else
                if !args.empty?
                    raise "start(...) args given but block is empty!\n"
                end

                pid = fork()
            end
            raise "Cannot fork #{$!}\n" if ! defined? pid

            if pid.nil?
                @in_child = true
            else
                @processes[pid] = identification
                on_start(pid, identification)
            end

            return pid
        else
            @processes[$$] = identification
            on_start($$, identification)

            return 0
        end        
    end

#
# finish(exit_code, [data_structure]) -- exit_code is optional
#
# finish() loses the child process by exiting and accepts an optional exit code.
# Default exit code is 0 and can be retrieved in the parent via callback.
# If you're running the program in debug mode (max_proc == 0), this method
# doesn't do anything.
#
# If <em>data_structure</em> is provided, then <em>data structure</em> is
# serialized and passed to the parent process. See <em>Retrieving Data
# Structures</em> in the next section for more info.  For example:
#
#    %w{Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry}.each {
#        |person|
#        # pm.start(...) here
#
#        # ... etc ...
#
#        # Pass along data structure to finish().
#        pm.finish(0, {'person' => person})
#    }
#
#
# === Retrieving Data Structures
#
# The ability for the parent to retrieve data structures from child processes
# was adapted to Parallel::ForkManager 1.5.0 (and newer) from Perl Parallel::ForkManager.
# This functionality was originally introduced in Perl Parallel::ForkManager
# 0.7.6.
#
# Each child process may optionally send 1 data structure back to the parent.
# By data structure, we mean a a string, hash, or array. The contents of the
# data structure are written out to temporary files on disk using the Marshal
# dump() method.  This data structure is then retrieved from within the code
# you send to the run_on_finish callback.
#
# NOTE NOTE NOTE: Only serialization with Marshal is supported at this time.
# Future versions of Parallel::ForkManager <em>may</em> support expanded functionality!
#
# There are 2 steps involved in retrieving data structures:
# 1. The data structure the child wishes to send back to the parent is provided as the second argument to the finish() call. It is up to the child to decide whether or not to send anything back to the parent.
# 2. The data structure is retrieved using the callback provided in the run_on_finish() method.
#
# Data structure retrieval is <em>not</em> the same as returning a data
# structure from a method call!  The data structure referenced by a given
# child process is serialized and written out to a file by <em>Marshal</em>.
# The file is subseqently read back into memory and a new data structure that
# belongs to the parent process is created.  Therefore it is recommended that
# you keep the returned structure small in size to mitigate any possible
# performance penalties.
#
    def finish(exit_code = 0, data_structure = nil)
        if @has_block
            raise "Do not use finish(...) when using blocks.  Use an explicit exit in your block instead!\n"
        end

        if @in_child
            exit_code ||= 0

            if !data_structure.nil?
                # Convert object to hash.  Else Marshal won't be
                # able to serialize it.
                #
                if data_structure.class.to_s.downcase == "object"
                    temp_data_structure = data_structure.to_hash
                    data_structure = temp_data_structure
                end

                @data_structure = data_structure
                the_tempfile = @tempdir
                the_tempfile = "#{@tempdir}Parallel-ForkManager-#{@parent_pid.to_s}-#{$$.to_s}.txt"
                
                begin
                    if @do_serialize == 1
                        if !_serialize_data(the_tempfile)
                            raise "Unable to serialize data!\n"
                        end
                    end
                rescue => e
                    print "Unable to store #{the_tempfile}: #{e.message}\n"
                    exit 1
                end
            end

            Kernel.exit!(exit_code)
        end

        if @max_procs == 0
            on_finish($$, exit_code, @processes[$$], 0, 0)
            @processes.delete($$)
        end
        return 0
    end
    
    def wait_children()
        return if @processes.keys().empty?

        kid = nil
        begin
            begin
                kid = wait_one_child(Process::WNOHANG)
            end while kid > 0 || kid < -1
        rescue Errno::ECHILD
            return
        end
    end
    
    alias :wait_childs :wait_children # compatibility

#
# Probably won't want to call this directly.  Just let wait_all_children(...)
# make the call for you.
#
    def wait_one_child(par)
        params = par || 0

        kid = nil
        while true
            # Call _NT_waitpid(...) if we're using a Windows or Java variant.
            if(RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince|emx|java/)
                kid = _NT_waitpid(-1, params)
            else
                kid = _waitpid(-1, params)
            end

            break if kid == nil or kid == -1 # Win32 returns negative PIDs

            redo if ! @processes.has_key?(kid)
            id = @processes.delete(kid)
            
            the_retr_data = {}
            the_tempfile = "#{@tempdir}Parallel-ForkManager-#{$$.to_s}-#{kid.to_s}.txt"
            
            begin
                if @do_serialize == 1
                    if File.exists?(the_tempfile) and ! File.zero?(the_tempfile)
                        if ! _unserialize_data(the_tempfile)
                            raise "Unable to unserialize data!\n"
                        end

                        the_retr_data = @data_structure
                    end
                end

                if File.exists?(the_tempfile)
                    File.unlink(the_tempfile)
                end
            rescue => e
                print "wait_one_child failed to retrieve object: #{e.message}\n"
                exit 1
            end

            on_finish(kid, $? >> 8, id, $? & 0x7f, $? & 0x80 ? 1 : 0, the_retr_data)
            break
        end

        kid ||= 0
        kid
    end

#
# wait_all_children() will wait for all the processes which have been 
# forked. This is a blocking wait.
#
    def wait_all_children()
        begin
            while ! @processes.keys().empty?
                on_wait()
                arg = (defined? @on_wait_period and !@on_wait_period.nil?) ? Process::WNOHANG : nil
                wait_one_child(arg)
            end
        rescue Errno::ECHILD
            return
        end
    end
    
    alias :wait_all_childs :wait_all_children # compatibility

#
# You can define run_on_finish(...) that is called when a child in the parent
# process when a child is terminated.
#
# The parameters of run_on_finish(...) are:
#
# - pid of the process, which is terminated
# - exit code of the program
# - identification of the process (if provided in the "start" method)
# - exit signal (0-127: signal name)
# - core dump (1 if there was core dump at exit)
# - data structure or nil (see Retrieving Data Structures)
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_finish will be deprecated in
# Parallel::ForkManager 1.5!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_finish supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#
#   pm.run_on_finish {
#           |pid,exit_code,ident|
#           print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
#   }
#
    def run_on_finish(code=nil, pid=0, &my_block)
        begin
            if !code.nil? && !my_block.nil?
                raise "run_on_finish: code and block are mutually exclusive options!"
            end

            if ! code.nil?
                if code.class.to_s == "Proc" and VERSION >= "1.5.0"
                    print "Passing Proc has been deprecated as of Parallel::ForkManager #{VERSION}!\nPlease refer to rdoc about how to change your code!\n"
                end
                @do_on_finish[pid] = code
            elsif !my_block.nil?
                @do_on_finish[pid] = my_block
            end
        rescue TypeError => e
            raise e.message
        end
    end

#
# on_finish is a private method and should not be called directly.
#
    def on_finish(*params)
        pid = params[0]
        code = @do_on_finish[pid] || @do_on_finish[0] or return 0
        begin
            my_argc = code.arity - 1
            if my_argc > 0
                my_params = params[0 .. my_argc]
            else
                my_params = [params[0]]
            end
            params = my_params
            code.call(*params)
        rescue => e
            raise "on finish failed: #{e.message}!\n"
        end
    end

#
# You can define a subroutine which is called when the child process needs
# to wait for the startup. If period is not defined, then one call is done per
# child. If period is defined, then code is called periodically and the
# method waits for "period" seconds betwen the two calls. Note, period can be
# fractional number also. The exact "period seconds" is not guaranteed,
# signals can shorten and the process scheduler can make it longer (i.e. on
# busy systems).
#
# No parameters are passed to code on the call.
#
# Example:
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_wait will be deprecated in
# Parallel::ForkManager 1.5!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_wait supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#   period = 0.5
#   pm.run_on_wait(period) {
#           print "** Have to wait for one child ...\n"
#   }
#
#

    def run_on_wait(*params, &block)
        begin
            raise "period is required by run_on_wait\n" if !params.length

            if params.length == 1
                period = params[0]
                raise "period must be of type float!\n" if period.class.to_s.downcase() != "float"
            elsif params.length == 2
                code, period = params
                raise "run_on_wait: Missing or invalid code block!\n" if code.class.to_s.downcase() != "proc"
            else
                raise "run_on_wait: Invalid argument count!\n"
            end

            @on_wait_period = period
            raise "Wait period must be greater than 0.0!\n" if period == 0

            if ! code.nil? && ! block.nil?
                raise "run_on_wait: code and block are mutually exclusive arguments!"
            end

            if ! code.nil?
                if code.class.to_s == "Proc" and VERSION >= "1.5.0"
                    print "Passing Proc has been deprecated as of Parallel::ForkManager #{VERSION}!\nPlease refer to rdoc about how to change your code!\n"
                end

                @do_on_wait = code
            elsif !block.nil?
                @do_on_wait = block
            end
        rescue TypeError
            raise "run on wait failed!\n"
        end
    end

#
# on_wait is a private method as it should not be called directly.
#
    def on_wait()
        begin
            if @do_on_wait.class().name == 'Proc'
                @do_on_wait.call()
                if defined? @on_wait_period and !@on_wait_period.nil?
                    #
                    # Unfortunately Ruby 1.8 has no concept of 'sigaction',
                    # so we're unable to check if a signal handler has
                    # already been installed for a given signal.  In this
                    # case it's no matter, since we define handler, but yikes.
                    #
                    Signal.trap("CHLD") do
                        lambda{}.call()
                    end
                    IO.select(nil, nil, nil, @on_wait_period)
                end
            end
        end
    end

#
# You can define a subroutine which is called when a child is started. It is
# called after a successful startup of a child in the parent process.
#
# The parameters of code are as follows:
# - pid of the process which has been started
# - identification of the process (if provided in the "start" method)
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_start has been deprecated as of Parallel::ForkManager 1.5!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_start supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#
#   pm.run_on_start() {
#           |pid,ident|
#           print "run on start ::: #{ident} (#{pid})\n"
#       }
#
# Note that code and block are mutually exclusive arguments.  If you try
# to use pass both a Proc and a block to run_on_start it will raise an error.
#
    def run_on_start(code=nil, &block)
        begin
            if ! code.nil? && ! block.nil?
                raise "run_on_start: code and block are mutually exclusive arguments!"
            end

            if ! code.nil?
                if code.class.to_s == "Proc" and VERSION >= "1.5.0"
                    print "Passing Proc has been deprecated as of Parallel::ForkManager #{VERSION}!\nPlease refer to rdoc about how to change your code!\n"
                end
                @do_on_start = code
            elsif !block.nil?
                @do_on_start = block
            end
        rescue TypeError
            raise "run on start failed!\n"
        end
    end

#
# on_start() is a private method as it should not be called directly.
#
    def on_start(*params)
        begin
            if @do_on_start.class().name == 'Proc'
                my_argc = @do_on_start.arity - 1
                if my_argc > 0
                    my_params = params[0 .. my_argc]    
                else
                    my_params = params[0]
                end
                params = my_params
                @do_on_start.call(*params)
            end
        rescue
            raise "on_start failed\n"
        end       
    end

#
# set_max_procs(mp) -- mp is an integer
#
# set_max_procs() allows you to set a new maximum number of children to maintain.
#
# Return: The previous setting of max_procs.
#
    def set_max_procs(mp=nil)
        if mp == nil
            return @max_procs
        else
            @max_procs = mp
        end
    end

#
# _waitpid(...) is a private method as it should not be called directly.
# It is called automatically by wait_one_child(...).
#
    def _waitpid(pid, flags)
        return waitpid(pid, flags)
    end

#
# _NT_waitpid(...) is a private method as it should not be called directly.
#
# _NT_waitpid(...) implements the Windows variant of _waitpid(...) and will
# be called automatically by wait_one_child(...) depending on the value of
# RUBY_PLATFORM.
#
    def _NT_waitpid(pid, par)
        if par == Process::WNOHANG
            pids = @processes.keys()
            if pids.length() == 0
                return -1
            end
            
            kid = 0
            for my_pid in pids
                kid = waitpid(my_pid, par)
                if kid != 0
                    return kid
                end
            return kid
            end
        else
            return waitpid(pid, par)    
        end
    end

#
# _serialize_data is a private method and should not be called directly.
#
# Currently only supports Marshal.dump() to serialize data.
#
    def _serialize_data(store_tempfile)
        retval = 0

        if @serialize_as == "marshal"
            begin
                f = File.new(store_tempfile, "wb")
            
                obj = Marshal.dump(@data_structure)
                f.write(obj)
            
                f.close()
            
                retval = 1
            rescue  => e
                raise "Error writing #{store_tempfile}: #{e.message}"
            end
        else
            print "Unsupported serialization method: #{@serialize_as}!\n"
        end
        
        return retval
    end

#
# _unserialize_data is a private method and should not be called directly.
#
# Currently only supports Marshal.load() to unserialize data.
#
    def _unserialize_data(store_tempfile)
        retval = 0

        if @serialize_as == "marshal"
            begin
                to_obj = String.new()

                f = File.new(store_tempfile, "rb")
            
                f.readlines.each {
                    |line|
                    to_obj << line
                }
            
                f.close()
            
                @data_structure = Marshal.load(to_obj)
                retval = 1
            rescue => e
                raise "Error reading #{store_tempfile}: #{e.message}"
                # Clean up temp file if it exists.
                # Otherwise we'll have a bunch of 'em laying around.
                #
                if File.exists?(store_tempfile)
                    File.unlink(store_tempfile)
                end
            end
        else
            print "Unsupported serialization method: #{@serialize_as}!\n"
        end

        return retval
    end

    # private methods
    private :on_start, :on_finish, :on_wait, :_waitpid, :_NT_waitpid
    private :_serialize_data, :_unserialize_data

end # class

end # module
