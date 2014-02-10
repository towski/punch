require 'ruboto/widget'
require 'ruboto/util/toast'
require 'ruboto/service'
require 'sender'
APP_DIR = File.expand_path File.dirname(__FILE__)
GEM_DIR = File.join(APP_DIR, 'vendor', 'gems')
Dir.entries(GEM_DIR).each do |dir| 
  $LOAD_PATH << File.join(GEM_DIR, dir, 'lib')
end
android.util.Log.v 'Punch', "Start"

begin
  require 'dbm'
  require 'dbm_orm'
  require 'picture'
  require 'request'
  Model.dir = Dir.pwd
  ruboto_import_widgets :Button, :LinearLayout, :TextView
rescue Exception => e
  android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
end

$index = 0

class RubotoService
  field_accessor :mClassName, :mBase, :mActivityManager

  def on_create
    android.util.Log.v 'Punch', "on create"
    super
  end

  def on_start_command(intent, flags, startId)
    android.util.Log.v 'Punch', "on start command #{Time.now}"
    Thread.new do
      loop do
        android.util.Log.v 'Punch', "start loop #{Time.now}"
        #services = $activity_manager.getRunningServices(50)
        #services.each do |service|
        #  android.util.Log.v 'Punch', "runningServiceInfo: #{service.service.getClassName} #{service.foreground}"
        #end
        begin
          sender = Sender.new
          sender.run
        rescue Exception => e
          sleep 10
          android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
        end
        android.util.Log.v 'Punch', "done sending"
      end
    end

    begin
    rescue Exception => e
      android.util.Log.v 'Punch', "#{e.inspect}"
      android.util.Log.v 'Punch', "#{e.backtrace}"
    end

    @ruboto_java_instance.class::START_STICKY
  end

  # doesn't work so I'm doing it in Java RubotoServer
  def try_to_set_foreground
    title = "IRB server running on "
    text = "Rerun the script to stop the server."
    ticker = "IRB server running on"
    icon = android.R::drawable::stat_sys_upload
    self.mBase = $app_context
    self.mActivityManager = Java::AndroidApp::ActivityManagerNative.get_default#$activity_manager.to_java(Java::AndroidApp::IActivityManager)
    self.mClassName = "QuickStartActivity"
    notification = android.app.Notification.new(icon, ticker, java.lang.System.currentTimeMillis)
    notification = Java::AndroidApp::Notification::Builder.new($activity.getApplicationContext).setContentTitle("Old New mail from #{Time.now}").setContentText("Me")
    intent = android.content.Intent.new($activity.getApplicationContext, QuickStartActivity.java_class)
    #intent.setFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP | android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP);
    #intent.setAction("org.ruboto.intent.action.LAUNCH_SCRIPT")
    #intent.addCategory("android.intent.category.DEFAULT")
    #intent.putExtra("org.ruboto.extra.SCRIPT_NAME", "demo-irb-server.rb")
    pending = android.app.PendingIntent.getActivity($app_context, 0, intent, 0)
    #notification.setLatestEventInfo($activity.getApplicationContext, title, text, pending)
    #notification.setLatestEventInfo(@ruboto_java_instance, title, text, pending)
    notification.setContentIntent(pending);
    start_foreground(10, notification.build)
  end

  def on_destroy
    android.util.Log.v 'Punch', "on destroy #{Time.now}"
  end
end

def start_intent_service(obj)
  begin
    obj.start_ruboto_service(nil, RubotoService){ 
      def on_start_command(intent, flags, startId)
        android.util.Log.v 'Punch', "onstart command #{Time.now}"
      end
    } #, :class_name => "Java::AndroidApp::IntentService") do
  rescue Exception => e
    android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
  end
end

def notification
  notification = Java::AndroidApp::Notification::Builder.new(@ruboto_java_instance).setContentTitle("New mail from").setContentText("Me").setSmallIcon(android.R::drawable::stat_sys_upload)
  resultIntent = android.content.Intent.new(self, QuickStartActivity.java_class);
  pending = android.app.PendingIntent.getActivity($app_context, 0, resultIntent, 0)
  notification.setContentIntent(pending);
  $notification.notify(1, notification.build)
end

class QuickStartActivity
  @@index = 0
  def onCreate(bundle)
    super
    return if @@index > 0
    $app_context = getApplicationContext
    $activity_manager = getSystemService(ACTIVITY_SERVICE);
    $notification = getSystemService(NOTIFICATION_SERVICE);
    $activity = self
    @@index += 1
    set_title 'Domo arigato, Mr Rubota!'
    @sender = nil
    @started = nil
    begin
      start_intent_service(self)
      # am = self.getSystemService(android.content.Context::AUDIO_SERVICE)
      # am.set_stream_volume(android.media.AudioManager::STREAM_SYSTEM, 0, 0)
      # formerly CameraDemoc ode
      # self.content_view = @surface_view
      android.util.Log.v "Punch", "#{$background_service}"
    rescue Exception => e
      android.util.Log.v 'Punch', "ERROR #{e.inspect} #{e.backtrace}"
    end
      @db = DBM.open("#{Dir.pwd}/pictures", 0666, DBM::WRCREAT)
    android.util.Log.v 'PunchTest', "threading"
    self.content_view = linear_layout :orientation => :vertical do
        @text_view = text_view :text => 'What hath Matz wrought?', :id => 42, 
                               :layout => {:width => :match_parent},
                               :gravity => :center, :text_size => 48.0
        button :text => 'M-x butterfly', 
               :layout => {:width => :match_parent},
               :id => 43, :on_click_listener => proc { get_latest_picture }
      end
  rescue Exception
    puts "Exception creating activity: #{$!}"
    puts $!.backtrace.join("\n")
  end

  def get_latest_picture
  end

  def onUserLeaveHint
    #android.util.Log.v 'Punch', "On User leave hint"
    #finish
  end

end
