#!/home/work/opbin/ruby/bin/ruby
#coding: utf-8
 
def open3(*cmd)
        # Prepare pipes (get read and write ends)
        in_r, in_w = IO.pipe
        out_r, out_w = IO.pipe
        err_r, err_w = IO.pipe
  
        # Do the forking
        child_pid = fork{
                # This is the child
  
                # Close the filehandlers that belong to the parent
                # (we inherited them, as all the other)
                in_w.close
                out_r.close
                err_r.close
  
                # "Reopen" standard file handlers in the child context
                STDIN.reopen(in_r)
                STDOUT.reopen(out_w)
                STDERR.reopen(err_w)
  
                # Do something in child context
                #ENV["ALTER_ENVIRONMENT"] = "for example"
  
                # Now we're prepared to exec the command
                exec(*cmd)
        }
        # This is the parent
        # Close the filehandlers that belong to the child
        in_r.close
        out_w.close
        err_w.close
  
        return [in_w,out_r,err_r,child_pid]
        # We might as well do this (read below):
        # return [in_w,out_r,err_r,child_pid]
end
 

#out = open3 "ls -alh"
#puts out[1].read



def open3_wrapper(input_string,out_callback,err_callback,command,*args)
  # Prepare buffers for buffered writes and reads (God help us if these are unicode strings!)
  inp_buf = input_string || ''
  out_buf = ''
  err_buf = ''
  # Chunks of this size will be read/written in one iteration.  Should be greater than the expected line length, but smaller than the pipe capacity
  chunk_size = 3096
 
  # Progressive timeout array
  sleeps = [ [0.05]*20,[0.1]*5,[0.5]*3,1,2].flatten
 
  inp,out,err,child_pid = open3(command,*args)
  still_open = [out,err]  # Array that only contains the opened streams
  while not still_open.empty?
    # Check if we have anything to write, and wait for input if we do
    should_write = (inp_buf.nil? || inp_buf.empty?) ? [] : [inp]
 
    # Adjust the progressive timeout (max time is 2 sec)
    timeout = sleeps.shift || timeout
 
    # Perform the select
    fhs = IO.select(still_open,should_write,nil,timeout)
 
    # Timeout elapsed
    unless fhs
      # Check if process is really alive or dead
      if Process.waitpid(child_pid, Process::WNOHANG)
        # Process is dead.  Return its status
        return $?
      else
        next
      end
    end
 
    # fhs[1] is an array that contains filehandlers we can write to
    #for pp in fhs[1]
    #  p pp.methods
    #  p pp.closed?
    #end
    if fhs[1].include? inp and not inp_buf.empty?
      for f in fhs[1]
        p "inp_buf inp: #{inp_buf}"
        #p f.methods
        #p f.fileno
      end
    end
      # We _have_ something to write, and _can_ write at least one byte
      #to_print, inp_buf = inp_buf[0..chunk_size-1],inp_buf[chunk_size..inp_buf.length-1]
      #inp_buf ||= ''  # the previous line would null-ify the buffer if it's less than chink_size
      # Perform a non-blocking write
      #written = inp.write to_print
     # p "#inp: #{inp.class}"
      #inp.write inp_buf
      # Add the non-written remains back to the buffer
      #inp_buf = to_print[written..to_print.length-1] + inp_buf
    #end
    # fhs[0] is an array that contains filehandlers we can read from
    if fhs[0].include? out
      begin
        # Perform a non-blocking read of chunk_size symbols, and add the contents to the buffer
        out_buf += out.readpartial(chunk_size)
        # Now we just split it into lines with regexp matching
        puts "----------------------------------------"
        puts "out_buf: #{out_buf}"
        puts "lambda: #{out_callback.lambda?}"
        while md = /(.*)\n/.match(out_buf)
          puts "#md : #{md.class}: #{md[1]}"
          if to_write = out_callback.call(md[1])
            # If output callback returns someting, add it to the child input buffer
            puts "inp_buf: #{to_write}"
            inp_buf += to_write
          else
            inp.close
          end
          out_buf = md.post_match
        end
      rescue EOFError  # If we have read everything from the pipe
        # Remove out from the list of open pipes
        still_open.delete_if {|s| s==out}
      end
    end
    if fhs[0].include? err
      begin
        # Perform a non-blocking read of chunk_size symbols, and add the contents to the buffer
        err_buf += err.readpartial(chunk_size)
        # Now we just split it into lines with regexp matching
        while md = /(.*)\n/.match(err_buf)
          if to_write = err_callback[md[1]]
            # If error callback returns someting, add it to the child input buffer
            inp_buf += to_write
          else
            inp.close
          end
          err_buf = md.post_match
        end
      rescue EOFError  # If we have read everything from the pipe
        # Remove err from the list of open pipes
        still_open.delete_if {|s| s==err}
      end
    end
  end
  # output pipes are closed, wait for the child and get its exit status
  Process.waitpid(child_pid)
  return $?
end
 
out_call = lambda {|line|
  number = line.to_i
  reply = number + 1
  puts "#number: #{number} reply: #{reply}"
  #STDOUT.printf("Got %d from STDOUT.  Replying with %d to child.\n",number,reply);
  # printf may have buffered the output.  Force it to the channel.
  #STDOUT.flush
  if reply < 5000
    return sprintf("%d\n",reply);
  else
    return nil
  end
}




 
err_call = lambda {|line|
  number = line.to_i
  reply = number + 1
  STDOUT.printf("Got %d from STDERR.  Replying with %d to child.\n",number,reply);
  # printf may have buffered the output.  Force it to the channel.
  STDOUT.flush
  if reply < 5000
    return sprintf("%d\n",reply);
  else
    return nil
  end
}
 



puts open3_wrapper("",out_call,err_call,"ls -alh");
# This also works (if you adjust the mount points), but you have to wait for some time for a program to terminate.
#puts open3_wrapper("a\n",out_call,err_call,"sshfs","pavel@localhost:.","/tmp/mountpt");

