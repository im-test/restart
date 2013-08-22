#coding: utf-8
$: << File.dirname(__FILE__)

require "open-uri"
require "timeout"
require "pathname"
require 'forkmanager'

require "log"
require "conf"

module OP
  include Conf
  include Mylog
 
  def debug(mesg, on=CONF["DEBUG"])
    if on == 1
      p mesg
      LOG.debug "#{mesg}"
    end
  end
 
  def exec_block(cmd,timeout=60)
    begin
      status = Timeout::timeout(timeout) {
        out = `#{cmd}`
        debug "func:#{__method__} output: #{out}"
        if $?.exitstatus != 0
            ERR.error "exec error: #{cmd}"
        end
        return [out,$?.exitstatus]
      }
    rescue Timeout::Error #=> ex
      debug "execute command: [#{cmd}] timeout"
      return [nil,2]
    rescue Errno::ENOENT => ex
      debug "err: #{ex}"
      return [nil,1]
    rescue => ex
      ERR.error "exec error-> command:#{ex}"
    end
  end
  
  def get_host_by_tag(tag)
    hs,extcode = exec_block("nodes search -p im --status=running --tags=#{tag}")
    #p "result:#{hs} tag:#{tag}"
    debug "func:#{__method__} result:#{hs} tag:#{tag}"
    if extcode != 0 or hs == ""
      ERR.error "nodes tags:#{tag} get host error"
      return []
    end
    hl = []
    hs.each_line {|line| hl << line.chomp}
    hl.uniq!
    hl
  end

  def get_tag_by_host(host)
    tags,extcode = exec_block("nodes search -n #{host}")
    if extcode == 0
      return /Tags: (.*)/.match(tags)[1].gsub(",","+")
    elsif extcode == 105
      return nil
    end
  end

  def get_host_by_lh(qstring)
    #if qstring.split("-")[0].split[","].length >= 0
    hs,extcode = exec_block("lh -h #{qstring}")
    debug "func:#{__method__} result:#{hs} qstring:#{qstring}"
    if /^0 results/.match(hs)
      return []
    elsif /lh: invalid/.match(hs)
      return []
    else
      hl = []
      hs.each_line {|line| hl << line.chomp}
      hl.delete_at -1
      hl.uniq!
      hl
    end
  end

  def get_qstring_by_host(host)
    qstring,extcode = exec_block("lh -r #{host}")
    qstring = qstring.split(":")[1].strip
    parts = qstring.split("-")
    part2 = parts[2].split(",")
    part3 = parts[3].split(",")
    if part2.length >= 2
      part2.each {|s| parts[2] = s if /[a-zA-Z]+[0-9]+/.match s}
    end
    if part3.length >= 2
      part3.each {|s| parts[3] = s if /[a-zA-Z]+[0-9]+/.match s}
    end
    #[parts[2], parts[3]].each do |part|
    #  parts = part.split(",")
    #  if parts.length >= 2
    return parts.join("-")    
  end 

  def get_host_by_file(file)
    if not File.exists? file
      ERR.error "host file: #{file} not exist."
      exit 1
    else
      list = []
      open(file) { |f|
        f.each_line do |line|
        list << line.strip if line.length != 0 
        end
       }
      list
    end
  end

 
  def exec_remote(host, cmd, timeout=1200)
    if host == "" or cmd == ""
      log::ERR.error "exec_remote host:#{host} cmd:#{cmd} parameters invalid"
      return 1
    end
    #LOG.info "#{CONF['SSH_CMD']} #{CONF['SSH_OPT']} #{host} \"#{cmd}\""
    debug "#{CONF['SSH_CMD']} #{CONF['SSH_OPT']} #{host} \"#{cmd}\""
    begin
      exec_block("#{CONF['SSH_CMD']} #{CONF['SSH_OPT']} #{host} \"#{cmd}\"",timeout=timeout)
    rescue => ex
      ERR.fatal "exec remote error. host:#{host}, command:#{cmd}"
      return 1
    end
  end
  
  module_function :exec_block,:exec_remote,:get_host_by_tag,:get_host_by_lh,:get_tag_by_host,:get_qstring_by_host,:debug,:get_host_by_file

  def add_blacklist_by_bl(qstring, rules)
    if rules.nil?
      LOG.info "add_blacklist qstring:#{qstring} rule: no rules to be shielded"
      return 0
    end
    if qstring == ""
      ERR.error "add_blacklist qstring:#{qstring} rule:#{rules} parameters invalid"
      return 0
    end
    rules = rules.split
    rules.each {|rule|
      shield_alarm_cmd = "bl -q add #{qstring} #{rule} > /dev/null"
      p shield_alarm_cmd
      exec_block(shield_alarm_cmd)
    }
    if $?.exitstatus == 0
      LOG.info "add_blacklist rule:#{rules} qstring:#{qstring} success"
      return 0
    end
  end

  def del_blacklist_by_bl(qstring, rules)
    if rules.nil?
      LOG.info "del_blacklist qstring:#{qstring} rule: no rules to be open"
      return 0
    end
    if qstring == ""
      ERR.error "del_blacklist qstring:#{qstring} rule:#{rules} parameters invalid"
      return 0
    end
    rules = rules.split
    rules.each {|rule|
      open_alarm_cmd = "bl -q del #{qstring} #{rule} > /dev/null"
      p open_alarm_cmd
      exec_block(open_alarm_cmd)
    }
    if $?.exitstatus == 0
      LOG.info "del_blacklist rule:#{rules} qstring:#{qstring} success"
      return 0
    end
  end

  def add_blacklist(host, rules)
    if host == "" or rule == ""
      ERR.error "add_blacklist host:#{host} rule:#{rule} parameters invalid"
      return 1
    end
    rulelist = rule.split()
    n = 0
    1.upto(RETRY) do
      rulelist.each do |rule|
        p "#{BLOCKCMD} add -h #{host} -r #{rule}"
        stdout,extcode = exec_block("#{BLOCKCMD} add -h #{host} -r #{rule}")
        ps = stdout.scan("OK!")
        if ps.size != 0
          stdout,extcode = exec_block("#{BLOCKCMD} show -h #{host}")
          ps = stdout.scan("Rule:#{rule}")
          if ps.size != 0
            LOG.info "add blacklist host:#{host} rule:#{rule} success"
            next
          end
        end
      sleep 0.2
      end
      return 0
    end
    ERR.error "#{BLOCKCMD} add -h #{host} -r #{rule} success error"
    return 1
  end
  
  
  def del_blacklist(host, rule)
    if host == "" or rule == ""
      ERR.error "del blacklist host:#{host} rule:#{rule} parameters invalid"
      return 1
    end
    n = 0
    1.upto(RETRY) do
      p "#{BLOCKCMD} del -h #{host} -r #{rule}"
      stdout,extcode = exec_block("#{BLOCKCMD} del -h #{host} -r #{rule}")
      ps = stdout.scan("OK!")
      if ps.size != 0
        stdout,extcode = exec_block("#{BLOCKCMD} show -h #{host}")
        ps = stdout.scan("Rule:#{rule}")
        if ps.size == 0
          LOG.info "del blacklist host:#{host} rule:#{rule} success"
          return 0
        end
      end
    end
    ERR.error "del blacklist host:#{host} rule:#{rule} error"
    return 1
  end

  
  def checkdata(host, path, data_size=50000)
    if host.empty? or path.empty?
        return [nil, 1]
    end
    retv,retc = exec_remote(host, "du -s #{path} 2> /dev/null", timeout=10)
    LOG.info "check data on: #{host}, return #{retv}, return value #{retc}"
    if retc == 0
      r = retv.split(/\t/)
      if r[0].to_i > data_size
        LOG.info "get data size.host:#{host} path:#{path} size:#{r[0]}"
        return [r[0], 0]
      else
        LOG.error "data size too short: #{path} size:#{r[0]}"
        return [r[0], 1]
      end
    else
      ERR.error "get data size error. host: #{host} path: #{path}"
      return [nil, 1]
    end
  end
  
  def checkalldata(hostlist, path, data_size=50000,mercy=1)
    done_list = []
    fail_list = []
    if hostlist.size == 0 or path.empty?
      return 2
    elsif hostlist.size == 1
      retv,retc = checkdata(hostlist[0],path,data_size)
      return retc
    end
    hostlist.shuffle!
    tmpsize,tmpret = checkdata(hostlist[0],path)
    if tmpret == 0
      for host in hostlist
        tmp_size,tmp_ret = checkdata(host, path, data_size)
        if tmp_ret == 0 and tmp_size == tmpsize
          done_list.push host
          LOG.info "check data size right.  host:#{host} path:#{path} size:#{tmp_size}"
          next
        else
          fail_list.push host
          ERR.fatal "check data error. host:#{host} path:#{path}"
        end
      end
    else
      fail_list = hostlist
    end
    return done_list,fail_list
  end

  def filter_blacklist(hostlist,blacklist,tags="")
    black = YAML::load(open(blacklist).read)
    blacknew = []
    taglist = tags.split(",")
    debug "taglist: #{taglist}"
    black.each_pair do |key,value|
      begin
        debug "blacklist label: #{key} has value #{value}"
        if taglist.include? key
          blacknew.concat(value.split(" "))
        end
      rescue NoMethodError
        debug "blacklist label: #{key} has value #{value}"
        next
      end
    end
    debug "hostlist: #{hostlist}, host in black: #{blacknew}"
    hostlist - blacknew
  end

  def multi_process(task_list = [], done_list = [], fail_list = [], concurrency=1, cmd="", threshold=1, timeout=600)
    p "concurrency: #{concurrency}"
    if cmd.size == 0
      debug "no command found"
      return nil
    end
    if task_list.size == 0
      debug "#{__method__}: no host found"
      exit 1
    end
    if concurrency.to_f/task_list.size > 0.5
       debug "concurrency too big"
       exit 1
    end
    while task_list.size != 0 do
      if fail_list.size >= threshold
        ERR.error "failed host count: #{fail_list.size}, beyond the thresold: #{threshold}"
        exit 1
      end
      doing_list = task_list.shift(concurrency)
      pm = Parallel::ForkManager.new(concurrency,{'tempdir' => '/tmp'}, 0)
      #callback
      pm.run_on_finish { # called BEFORE the first call to start()
        |pid,exit_code,ident,exit_signal,core_dump,data_structure|

        # retrieve data structure from child
        if defined? data_structure # children are not forced to send anything
          if exit_code == 0
            done_list << data_structure
          else
            fail_list << data_structure
          end
        end
      }

      doing_list.each do |host|
        pid = pm.start(host) and next
        # The code in the child process
        debug "execute: #{cmd} on #{host}"
        out,ret = exec_remote(host,cmd,timeout=timeout)
        if ret != 0
          ERR.error "cmd on host:#{host} error"
          pm.finish(1, {host => out})
        else
          LOG.info "cmd on host:#{host} out: #{out}, #{cmd} success"
          #LOG.info "cmd on host:#{host} success"
          pm.finish(0, {host => out}) # pass an exit code to finish
        end
      end
    pm.wait_all_children
    end
    #return 0
  end

  module_function :checkdata,:checkalldata,:add_blacklist,:del_blacklist,:add_blacklist_by_bl,:filter_blacklist,:multi_process

end


#include OP
#$tasklist = ["yf-imbp-rms00-00.yf01","yf-imbp-rms01-00.yf01","yf-imbp-rms02-00.yf01","yf-imbp-rms03-00.yf01","yf-imnsbp-rms00-00.yf01","yf-imnsbp-rms01-00.yf01","yf-imnsbp-rms02-00.yf01","yf-imnsbp-rms03-00.yf01"]
#$doinglist = []
#$donelist = []
#$faillist = []
#multi_process(task_list=$tasklist, done_list=$donelist,fail_list=$faillist,concurrency=1,cmd="hostname -i;sleep 1;du -s dynamic_data/retrms/explore")
#p "donelist:#{$donelist}"
#p "faillist: #{$faillist}"


#p OP::filter_blacklist(["yf-imbp-rms00-00.yf01","yf-imbp-rms01-00.yf01","yf-imbp-rms02-00.yf01","yf-imbp-rms03-00.yf01"],OP::CSCONF["global"]["blacklist"]["url"],OP::CSCONF["platform"]["bp"]["blacklist"])


#p checkdata("yf-imps-npgrbs00-04.yf01", "/home/work/dynamic_data/retrbs/model")
#p get_hostlist("d0+retrms")
#p exec_block("du -sh *")
#p OP::get_host_by_tag("retrms+[deptest2,deptest3]")
#p OP::get_host_by_lh("hz01-cs-imps-ras")
#p OP::get_qstring_by_host("yf-imps-ras12.yf01")
#p OP::get_host_by_lh(OP::get_qstring_by_host("yf-imps-ras12.yf01"))
#p OP::get_tag_by_host("yf-imps-ras12.yf01")
#p OP::get_host_by_tag(OP::get_tag_by_host("yf-imps-ras12.yf01"))
