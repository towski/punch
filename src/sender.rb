require 'socket'

CRLF = "\r\n"

class Sender
  attr_accessor :camera_data

  def puts msg
    android.util.Log.v 'Punch', msg
  end

  def run
    begin
      sock = TCPSocket.new 'towski.us', 4444
      sock.write("hey")
      remote_host, remote_port = sock.read.split(":")
      puts "readed #{remote_host}"
      sock.close
    rescue => e
      puts e.inspect
    end

    remote_port = 6311
    # Punches hole in firewall
    punch = UDPSocket.new
    punch.bind('', remote_port)
    punch.send('', 0, remote_host, remote_port)
    punch.close

    # Bind for receiving
    udp_in = UDPSocket.new
    udp_in.bind('0.0.0.0', 6311)
    puts "Binding to local port 6311"
    @start = false

    loop do
      # Receive data or time out after 5 seconds
      if IO.select([udp_in], nil, nil, rand(4))
        data = udp_in.recvfrom(1024)
        remote_port = data[1][1]
        remote_addr = data[1][3]
        puts "Response from #{remote_addr}:#{remote_port} is #{data[0]}"
        if data[0] == "got"
          puts 'got handy'
          @start = true
        end
        if @start
          puts 'sending handy'
          udp_in.send("handy", 0, remote_host, remote_port)
        else
          puts "Sending a little something.."
          udp_in.send(Time.now.to_s, 0, remote_host, remote_port)
        end
      else
        #if we time out, we know the other guy has started
        puts "actually timed out"
        i = 0
        if @start
          puts "going to send #{camera_data}"
          file = File.open(camera_data)
          puts "opened file"
          while content = file.read(100)
            begin
              udp_in.send(content, 0, remote_host, remote_port)
            rescue Exception => e
              puts e.inspect
              puts content.inspect
              break
            end
          end
          puts "done sending"
          udp_in.send(CRLF, 0, remote_host, remote_port)
          sleep 3
          udp_in.close
          return
        else
          puts "Sending a little something.."
          udp_in.send(Time.now.to_s, 0, remote_host, remote_port)
        end
      end
    end
  end
end
