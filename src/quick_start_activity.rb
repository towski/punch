require 'ruboto/widget'
require 'ruboto/util/toast'
#require 'camera_helper'
require 'sender'
#require 'receiver'

ruboto_import_widgets :Button, :LinearLayout, :TextView

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
			android.util.Log.v 'Punch', "trying to make view #{@@index}"
			@surface_view = android.view.SurfaceView.new self #(@ruboto_java_instance)
			android.util.Log.v 'Punch', "got view"
			@surface_view.set_on_click_listener{|v| take_picture}
			@holder_callback = RubotoSurfaceHolderCallback.new
			@surface_view.holder.add_callback @holder_callback
			# Deprecated, but still required for older API version
			@surface_view.holder.set_type android.view.SurfaceHolder::SURFACE_TYPE_PUSH_BUFFERS
			am = self.getSystemService(android.content.Context::AUDIO_SERVICE)
			am.set_stream_volume(android.media.AudioManager::STREAM_SYSTEM, 0, 0)
			android.util.Log.v 'Punch', "volume off"
			self.content_view = @surface_view
		rescue Exception => e
			android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
		end
    #self.content_view =
    #    linear_layout :orientation => :vertical do
    #      @text_view = text_view :text => 'What hath Matz wrought?', :id => 42, 
    #                             :layout => {:width => :match_parent},
    #                             :gravity => :center, :text_size => 48.0
    #      button :text => 'M-x butterfly', 
    #             :layout => {:width => :match_parent},
    #             :id => 43, :on_click_listener => proc { butterfly }
    #    end
  rescue Exception
    puts "Exception creating activity: #{$!}"
    puts $!.backtrace.join("\n")
  end

	def onUserLeaveHint
		android.util.Log.v 'Punch', "On User leave hint"
		finish
	end

  private

  def do_nothing
  end

  def butterfly
    @text_view.text = 'What hath Matz wrought!'
    begin
    rescue => e
      android.util.Log.v 'Punch', "create camera failed #{e.backtrace}"
    end
    toast "stuffing"
    if false #@started.nil?
      begin
        @started = Thread.new do 
          s = Sender.new
          android.util.Log.v 'Punch', "take picture"
          #CameraHelper.take_picture(s, @camera)
          #s = Receiver.new
          android.util.Log.v 'Punch', "running sender"
          #s.run
        end
      rescue Exception => e
        android.util.Log.v 'Punch', "onPause got called! #{e.inspect}"
      end
    else
      @started.kill
      @started = nil
    end
  end

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
        @sender = Sender.new
        @sender.camera_data = picture_file
        android.util.Log.v 'Punch', "what now"
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
