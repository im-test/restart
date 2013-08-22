 require 'rubygems'
 require 'forkmanager'

 max_procs = 2
 persons = %w{Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry}

 pm = Parallel::ForkManager.new(max_procs, {'tempdir' => '/tmp'}, 0)

 # data structure retrieval and handling
 pm.run_on_finish { # called BEFORE the first call to start()
     |pid,exit_code,ident,exit_signal,core_dump,data_structure|

     # retrieve data structure from child
     if defined? data_structure # children are not forced to send anything
         str = data_structure # child passed a string
         print "#{str}\n"
     else  # problems occuring during storage or retrieval will throw a warning
         print "No message received from child process #{pid}!\n"
     end
 }

 # prep random statement components
 foods = ['chocolate', 'ice cream', 'peanut butter', 'pickles', 'pizza', 'bacon', 'pancakes', 'spaghetti', 'cookies']
 preferences = ['loves', 'can\'t stand', 'always wants more', 'will walk 100 miles for', 'only eats', 'would starve rather than eat']

 # run the parallel processes
 persons.each {
     |person|
     pm.start() and next

     # generate a random statement about food preferences
     pref_idx = preferences.index(preferences.sort_by{ rand }[0])
     food_idx = foods.index(foods.sort_by{ rand }[0])
     statement = "#{person} #{preferences[pref_idx]} #{foods[food_idx]}"

     # send it back to the parent process
     pm.finish(0, statement)
 }

 pm.wait_all_children
