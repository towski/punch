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

#class CameraDemo
#  def on_create(bundle)
#    super
#    @surface_view = android.view.SurfaceView.new(@ruboto_java_instance)
#    @surface_view.set_on_click_listener{|v| take_picture}
#    @holder_callback = RubotoSurfaceHolderCallback.new
#    @surface_view.holder.add_callback @holder_callback
#    # Deprecated, but still required for older API version
#    @surface_view.holder.set_type android.view.SurfaceHolder::SURFACE_TYPE_PUSH_BUFFERS
#    self.content_view = @surface_view
#  end
#end
