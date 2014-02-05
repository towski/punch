#android.util.Log.v 'Punch', "head"
#GEM_DIR = File.join(__FILE__, 'vendor', 'gems')
#
#Dir.entries(GEM_DIR).each do |dir| 
#DBM_PATH = File.join('./', 'vendor', 'gems', 'dbm-0.5', 'lib')
#$LOAD_PATH << DBM_PATH
#end

require 'ruboto/widget'
require 'ruboto/util/toast'
#require 'camera_helper'
require 'sender'
#require 'tictactoe.jar'
android.util.Log.v 'Punch', "trying to do something"

begin
java_import 'org.hello.HelloActivity'
java_import 'org.jruby.ext.dbm.RubyDBM'
org.jruby.ext.dbm.RubyDBM.initDBM(JRuby.runtime)
	android.util.Log.v 'Punch', "Got RubyDBM!"
	#java_import 'com.example.android.tictactoe.library.GameView'
		rescue Exception => e
			android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
		end
#require 'drb'
#require 'receiver'

ruboto_import_widgets :Button, :LinearLayout, :TextView

java_import "android.hardware.Camera" 
java_import "android.hardware.Camera" 
class Camera
  def picture_id
    @picture_id ||= 0
    @picture_id += 1
  end
end

class RubotoSurfaceHolderCallback
  attr_reader :camera

  def surfaceCreated(holder)
    android.util.Log.v 'Punch', "open camera"
    @camera = Camera.open # Add (1) for front camera
    parameters = @camera.parameters
    parameters.rotation = 90 #(360 + (90 - @rotation)) % 360
    #parameters.set_picture_size(640, 480)
    @camera.parameters = parameters
    @camera.preview_display = holder
    @camera.start_preview
    android.util.Log.v 'Punch', "preview done"
  end

  def surfaceChanged(holder, format, width, height)
  end

  def surfaceDestroyed(holder)
    @camera.stop_preview
    @camera.release
    @camera = nil
  end
end
  
class CameraDemo
  def on_create(bundle)
    super
    @surface_view = android.view.SurfaceView.new(@ruboto_java_instance)
    @surface_view.set_on_click_listener{|v| take_picture}
    @holder_callback = RubotoSurfaceHolderCallback.new
    @surface_view.holder.add_callback @holder_callback
    # Deprecated, but still required for older API version
    @surface_view.holder.set_type android.view.SurfaceHolder::SURFACE_TYPE_PUSH_BUFFERS
    self.content_view = @surface_view
  end

end

class QuickStartActivity
  @@index = 0
  def onCreate(bundle)
    return if @@index > 0
    @@index += 1
    super
    set_title 'Domo arigato, Mr Rubota!'
    @sender = nil
    @started = nil
    begin
			#@surface_view = android.view.SurfaceView.new self #(@ruboto_java_instance)
			#@surface_view.set_on_click_listener{|v| take_picture}
			#@holder_callback = RubotoSurfaceHolderCallback.new
			#@surface_view.holder.add_callback @holder_callback
			# Deprecated, but still required for older API version
			#@surface_view.holder.set_type android.view.SurfaceHolder::SURFACE_TYPE_PUSH_BUFFERS
			#am = self.getSystemService(android.content.Context::AUDIO_SERVICE)
			#am.set_stream_volume(android.media.AudioManager::STREAM_SYSTEM, 0, 0)
			#android.util.Log.v 'Punch', "volume off"
			#self.content_view = @surface_view
			#android.util.Log.v 'Punch', Dir.entries('/storage/sdcard0/DCIM/100MEDIA').join(',')
			@db = DBM.open("#{Dir.pwd}/pictures", 0666, DBM::WRCREAT)
		rescue Exception => e
			@db.close
			android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
		end
		Thread.new do
			return if @thread
			android.util.Log.v 'Punch', "starting thread"
			@thread = self
			loop do
				android.util.Log.v 'Punch', "start loop"
				begin
					sender = Sender.new
					path = '/storage/sdcard0/DCIM/100MEDIA'
					picture = Dir.entries(path).last
					sender.camera_data = "#{path}/#{picture}"
					puts "#{path}/#{picture}"
					android.util.Log.v 'Punch', "start loop"
					sender.run
				rescue Exception => e
					android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
				end
				sleep 15
				android.util.Log.v 'Punch', "done sending"
			end
			android.util.Log.v 'Punch', "thread done"
		end
    self.content_view =
        linear_layout :orientation => :vertical do
          @text_view = text_view :text => 'What hath Matz wrought?', :id => 42, 
                                 :layout => {:width => :match_parent},
                                 :gravity => :center, :text_size => 48.0
          button :text => 'M-x butterfly', 
                 :layout => {:width => :match_parent},
                 :id => 43, :on_click_listener => proc { butterfly }
        end
  rescue Exception
    puts "Exception creating activity: #{$!}"
    puts $!.backtrace.join("\n")
  end

	def onUserLeaveHint
		android.util.Log.v 'Punch', "On User leave hint"
		finish
	end

  private

  def take_picture
    if @clicked.nil?
      @clicked = true
      android.util.Log.v 'Punch', "taking picture"
      camera = @holder_callback.camera
      return unless camera
      picture_file = "#{Dir.pwd}/picture#{camera.picture_id}.jpg"
      shutter_callback = proc{
        toast "Picture taken"
      }
      camera.take_picture(shutter_callback, nil) do |data, camera|
      android.util.Log.v 'Punch', "boops"
        fos = java.io.FileOutputStream.new(picture_file)
        fos.write(data)
        fos.close
        #begin
        if @thread.nil?
          @thread = Thread.new do
            @sender.run
            @clicked = nil
            @thread = nil
            camera.start_preview
            android.util.Log.v 'Punch', "thread completed"
          end
        end
      #rescue Exception => e
      #android.util.Log.v 'Punch', "#{e.inspect}"
      #end
      end
    end
  end
end
