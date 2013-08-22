#!/usr/bin/env ruby
#coding: utf-8
$: << File.dirname(__FILE__)

require "date"
require "open3"
require "timeout"
require "yaml"
require "pathname"
require "logger"
require "optparse"
require 'open-uri'

require 'forkmanager'
require "conf"
require "common"

include Process
include Conf
include OP


begin
    @options={}
    OptionParser.new do |opts|
        opts.banner = '-----update dynamic data and restart service or do something else-----

Usage: restart.rb [options]'
        opts.separator '       restart.rb [-f file] [-m module] [-p plat] [-r redo] [-d debug] [-h help]'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-f file', '--file hostlist file', 'file contains hostlist, one host per line'){
            |v| @options[:file] = v
        }

        opts.on('-m module', '--module module', 'module'){
            |v| @options[:module] = v
        }

      #  opts.on('-q qstring', '--qstring qstring', 'qstring'){
      #      |v| @options[:qstring] = v
      #  }

      #  opts.on('-t tags', '--tags tags', 'nodes tags'){
      #      |v| @options[:tags] = v
      #  }

        opts.on('-p platform', '--platform platform', 'platform in conf'){
            |v| @options[:plat] = v
        }

        @options[:redo] = false
        opts.on('-r', '--redo', 'redo host in dumped failed file'){
            |v| @options[:redo] = true
        }

        @options[:debug] = false
        opts.on('-d', '--debug', 'debug script, more log') {
            |v| @options[:debug] = true 
        }

        opts.on('-h', '--help', 'show help info') {
            puts opts
            exit 0
        }
    end.parse!
    if ARGV.length > 0
        puts 'invalid option: %s' % ARGV.join(' ')
        exit 1
    end
rescue => e
    puts e
    exit 1
end


if not @options.has_key? :plat
  if not @options.has_key? :file
    p "-p or -f should be one args"
    exit 1
  else
    if not @options.has_key? :module
      p "-m should be with -p"
      exit 1
    end
    hostlist = get_host_by_file @options[:file]
    p "processing model: #{@options[:module]}, host:#{hostlist}]"
    debug "processing model: #{@options[:module]}, host:#{hostlist}]"
  end
else
  if @options.has_key? :file
    p "-p and -f both be args, -f will be ignored."
  end
  plat = CSCONF["platform"]["#{@options[:plat]}"]
  if not plat["dependency"].nil? and plat["dependency"].size !=0
    plat["dependency"].each {|m|
      debug "process module: -----------------#{m}---------------"
      hostlist = get_host_by_lh(plat["#{m}_qstring"])
      debug "get_host_by_lh:  module: #{m},   hostlist: #{hostlist}"
      hostlist = filter_blacklist(hostlist,CSCONF["global"]["blacklist"]["url"],plat["blacklist"])
      debug "module: #{m}, after filter black  hostlist: #{hostlist}"
      concurrency = plat["concurrency"]
      #----------------------------------
      #check data
      #----------------------------------
      $goodlist = []
      $badlist = []
      datalist = []
      #p "plat: #{plat}"
      debug "origin data type in global conf: #{plat["#{m}_datalist"]}"
      if not plat["#{m}_datalist"] == []
        datalist_tmp = plat["#{m}_datalist"]
      else
        datalist_tmp = CSCONF["global"][m]["datalist"]
      end
      debug "datalist_tmp: #{datalist_tmp}"
      if datalist_tmp != nil and datalist_tmp.size != 0
        datalist_tmp.each do |datatype|
          datapath = CSCONF["global"][m]["#{datatype}_src"]
          debug datapath
          sleep 1
          oklist,faillist = checkalldata(hostlist,datapath)
          debug "ok list: #{oklist}, faillist: #{faillist}"
          next if oklist.size == 0
          if faillist.size.to_f/hostlist.size < CSCONF["global"][m]["mercy"]/100.0
            datalist << datatype
            $badlist.concat faillist
          end
        end
          debug "bad list after data check: #{$badlist}"
          if $badlist.size > plat["mercy"]
            debug "check data not pass. bad list: #{$badlist}"
            next
          else
            debug "check data pass"
          end
        
      end
      debug "datatype after checkdata: #{datalist}"
      p "pre cmd: #{CSCONF["global"][m]["pre_cmd"]}"
      p "post cmd: #{CSCONF["global"][m]["post_cmd"]}"
      if datalist.size == 0 && CSCONF["global"][m]["pre_cmd"].nil? && CSCONF["global"][m]["post_cmd"].nil?
        LOG.info "no data need substitute in #{m}"
        #next
        exit 0
      end
      #----------------------------------
      #make command to be execute on host
      #----------------------------------
      cmd_list = []
      if CSCONF["global"][m]["pre_cmd"].size != 0
        cmd_list.push CSCONF["global"][m]["pre_cmd"]
      end
      if datalist != nil and datalist.size != 0
        datalist.each do |datatype|
          cmd_list.push %Q!rm -rf #{CSCONF["global"][m]["#{datatype}_dst"]}.bak && mv #{CSCONF["global"][m]["#{datatype}_dst"]}  #{CSCONF["global"][m]["#{datatype}_dst"]}.bak && mv #{CSCONF["global"][m]["#{datatype}_src"]} #{CSCONF["global"][m]["#{datatype}_dst"]}!
        end
      end
      if CSCONF["global"][m]["restart"]
        cmd_list.push "cd /home/work/#{m}/bin && ./#{m}_control stop && ./#{m}_control start"
      end
      if CSCONF["global"][m]["post_cmd"].size != 0
        cmd_list.push CSCONF["global"][m]["post_cmd"]
      end
      debug "command to excute: #{cmd_list.join(" && ")}"
      sleep 2
      debug "origin host list: #{hostlist}, size: #{hostlist.size}"
      debug "after data check list: #{hostlist - $badlist}, size: #{(hostlist - $badlist).size}"


      #shield alarm
      rules = CSCONF["global"][m]["alarm_rule"]
      add_blacklist_by_bl(plat["#{m}_qstring"], CSCONF["global"][m]["alarm_rule"])
        
      #execute command on remote host
      $done_list ||= []
      $fail_list ||= [] 
      multi_process(task_list=hostlist, done_list=$done_list,fail_list=$fail_list,concurrency=plat["concurrency"],cmd="#{cmd_list.join(" && ")}",threshold=plat["mercy"])
     
      #open alarm
      del_blacklist_by_bl(plat["#{m}_qstring"], CSCONF["global"][m]["alarm_rule"])


      #dump failed host
      p "fail list: #{$fail_list}"
      p "bad list: #{$badlist}"
      p "done list: #{done_list}"
      if $fail_list.size !=0
        $fail_list.each { |h|
          $badlist.concat h.keys
        }
      end
      fail_file = (DATADIR+"fail_list_#{@options[:plat]}_#{m}").to_path
      if $badlist.size != 0
        failf = open(fail_file,"wb")
        $badlist.each {|h| failf.write(h+"\n")}
        failf.close
      end
        
      p "fail list: #{$fail_list}"
      p "bad list: #{$badlist}"
      p "done list: #{done_list}"

    }
  end
end

p @options

