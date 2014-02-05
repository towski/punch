require 'java'
java_import java.lang.System
version = System.getProperties["java.runtime.version"]
android.util.Log.v 'Punch', version

dir_name = File.dirname(__FILE__)
android.util.Log.v 'Punch', 'hey'
require "mapdb.jar"
require "dbm.jar"
include_class 'org.jruby.ext.dbm.RubyDBM'
library = org.jruby.ext.dbm.RubyDBMNS.new
#library.initDBM(JRuby.runtime)
#android.util.Log.v 'Punch', "init"
library.initDBM(JRuby.runtime)

class DBM
  def replace(other)
    clear
    update(other)
  end
  
  def update(other)
    other.each_pair { |k, v| self[k] = v }
    self
  end
end

