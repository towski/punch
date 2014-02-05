require 'ruboto'
ANDROID_HOME = ENV["ANDROID_HOME"]
android_jar = Dir["#{ANDROID_HOME.gsub("\\", '/')}/platforms/*/android.jar"][0]
android_jar.gsub!(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
class_path = ['.', "#{Ruboto::ASSETS}/libs/dx.jar","../libs/jruby-complete-1.7.10.jar", "../libs/mapdb.jar"].join(File::PATH_SEPARATOR).gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
`rm org/jruby/ext/dbm/*class`

# classpath , '/home/towski/code/punch/bin/classes'
# sourcepath, '/home/towski/code/punch/src:/home/towski/code/punch/gen'
options = ['javac', '-d',
'/home/towski/code/punch/build',
'-classpath',
'/home/towski/code/punch/libs/bundle.jar:/home/towski/code/punch/libs/mapdb.jar:/home/towski/code/punch/libs/jruby-complete-1.7.10.jar',
'-sourcepath',
'/home/towski/code/punch/gen:/home/towski/code/punch/build',
'-target',
'1.5',
'-bootclasspath',
'/home/towski/android-sdk-linux/platforms/android-16/android.jar',
'-encoding',
'UTF-8',
'-g',
'-source',
'1.5',
'/home/towski/code/punch/build/org/jruby/ext/dbm/*']

cmd = options.join(" ")
#cmd = "javac -source 1.6 -target 1.6 -cp #{class_path} -bootclasspath #{android_jar} -d . org/jruby/ext/dbm/*.java"
puts cmd
system(cmd)
`jar cvfe dbm.jar RubyDBM org/jruby/ext/dbm/*.class`
