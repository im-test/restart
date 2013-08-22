#coding: utf-8
$: << File.dirname(__FILE__)


require "pathname"
require "yaml"

$opconf = "op.conf"
$csconf = "cs.conf"

module Conf

  def get_rootdir    #re-construct
    root_bin = File.dirname(File.absolute_path(__FILE__))
    Dir.chdir(root_bin)
    Dir.chdir("..")
    Dir.pwd
  end
 
  def read_conf(conf_file)
    YAML::load(File.open(conf_file))
  end
 
  def dump_conf(conf_file, conf)
    YAML::dump(conf, File.open(conf_file, "w"))
  end

  module_function :get_rootdir,:read_conf,:dump_conf
 
  CURRENTDIR = Dir.pwd
  ROOTPATH = Pathname.new("#{get_rootdir}")
  LOGDIR = ROOTPATH + "log"
  CONFDIR = ROOTPATH + "bin"
  BINDIR = ROOTPATH + "bin"
  DATADIR = ROOTPATH + "data"
  #Dir.chdir(BINDIR.to_path)
   
  CONF = read_conf("#{(CONFDIR+$opconf).to_path}")
  CSCONF = read_conf("#{(CONFDIR+$csconf).to_path}")  
  Dir.chdir(CURRENTDIR)
end 

