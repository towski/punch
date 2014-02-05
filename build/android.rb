require 'ruboto'
ANDROID_HOME = ENV["ANDROID_HOME"]
android_jar = Dir["#{ANDROID_HOME.gsub("\\", '/')}/platforms/*/android.jar"][0]
android_jar.gsub!(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
class_path = ['.', "#{Ruboto::ASSETS}/libs/dx.jar","../libs/jruby-complete-1.7.10.jar", "../libs/mapdb.jar"].join(File::PATH_SEPARATOR).gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
`rm org/jruby/ext/dbm/*class`
cmd = "javac -source 1.6 -target 1.6 -cp #{class_path} -bootclasspath #{android_jar} -d . org/jruby/ext/dbm/*.java"
puts cmd
system(cmd)
`jar cvfe dbm.jar RubyDBM org/jruby/ext/dbm/*.class`
