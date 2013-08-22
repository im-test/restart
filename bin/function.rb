#coding: utf-8
$: << File.dirname(__FILE__)


require "find"
require "pathname"


module SA

  def list_file(directory)
    filelist = []
    dirlist = []
    other = []
    if not FileTest.exists? directory
      p "func:#{__method__} directory:#{directory} doesn't exist"
      return 1
    end
    if FileTest.symlink? directory
      directory = Pathname.new(directory).realpath.to_path
    end
    Find.find(directory) do |path|
      if FileTest.file? path
        filelist << path
      elsif FileTest.directory? path
        dirlist << path
      else
        other << path
      end
    end
    return filelist,dirlist,other
  end

  def hashdiff(h1,h2)
    #p "hash1: #{h1.to_s}, hash2: #{h2.to_s}"
    #only deal with hash
    if not h1.is_a? Hash or not h2.is_a? Hash
      p "object type wrong"
      return 1
    end

    #size is 0
    if h1.size == 0 and h2.size == 0
      return {}
    elsif h1.size == 0 and h2.size != 0
      return h2
    elsif h1.size != 0 and h2.size == 0
      return h1
    end


    not_equal = []


    #compare keys
    keys_h1 = h1.keys
    keys_h2 = h2.keys
    keys_in_both = keys_h1 & keys_h2
    keys_only_in_h1 = keys_h1 - keys_h2
    keys_only_in_h2 = keys_h2 - keys_h1
    
    #p "key in both: #{keys_in_both.to_s}"
    #p "key only in h1: #{keys_only_in_h1.to_s}"
    #p "key only in h2: #{keys_only_in_h2.to_s}"
   
    keys_in_both.map do |key|
      if not h1[key].eql? h2[key]
        not_equal << {key=>[h1[key],h2[key]]}
      end
    end

    return not_equal, keys_only_in_h1.map {|key| {key=>h1[key]}}, keys_only_in_h2.map {|key| {key=>h2[key]}}




  end


  module_function :list_file,:hashdiff

end

#p SA::list_file(["/home/work/testdir","/home/work/test"])
#p SA::hashdiff({:a=>1,:b=>2,:c=>3},{:a=>1,:b=>3,:d=>4})
