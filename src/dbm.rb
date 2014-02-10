library = org.jruby.ext.dbm.DBMLibrary.new
library.load(JRuby.runtime, false)

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
