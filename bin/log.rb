#coding: utf-8
$: << File.dirname(__FILE__)


require "logger"
require "conf"

module Mylog
  include Conf

  logfile = (LOGDIR + CONF["logfile"]).to_path
  errfile = (LOGDIR + CONF["errfile"]).to_path
  
  LOG = Logger.new(logfile, "daily")
  ERR = Logger.new(errfile, "daily")

  LOG.level = Logger::DEBUG
  ERR.level = Logger::DEBUG
  
  LOG.formatter = proc do |severity, datetime, progname, msg|
    "#{severity}: #{datetime} #{msg}\n"
  end
  
  ERR.formatter = proc do |severity, datetime, progname, msg|
    "#{severity}: #{datetime} #{msg}\n"
  end
  
  LOG.datetime_format = "%Y-%m-%d %H:%M:%S"
  ERR.datetime_format = "%Y-%m-%d %H:%M:%S"

end

