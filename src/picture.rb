class Picture < Model
  def send_data(udp_in, remote_host, remote_port)
    android.util.Log.v 'Punch', "going to send #{filename}"
    file = File.open(filename)
    android.util.Log.v 'Punch', "opened file"
    while content = file.read(512)
      begin
        udp_in.send(content, 0, remote_host, remote_port)
      rescue Exception => e
        android.util.Log.v 'Punch', e.inspect
        android.util.Log.v 'Punch', content.inspect
        break
      end
    end
    android.util.Log.v 'Punch', "done sending"
  end

  def self.get_latest
    path = '/storage/sdcard0/DCIM/100MEDIA/'
    entries = Dir.entries(path)
    entries.sort_by!{|e| File.mtime("#{path}#{e}") }
    entries.each do |file|
      next if file == "." || file == ".."
      next if Picture.db[file]
      picture = Picture.new(:filename => "#{path}#{file}", :mtime => File.mtime("#{path}#{file}"))
      picture.save
      Picture.db[file] = 1
    end
  end
end
