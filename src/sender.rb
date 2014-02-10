require 'socket'
require 'timeout'

CRLF = "\r\n"

class Sender
  attr_accessor :camera_data

  def puts msg
    android.util.Log.v 'Punch', msg
  end

  def run
    android.util.Log.v 'Punch', "starting sleep on port"
    begin
      domain = "ec2-54-196-239-114.compute-1.amazonaws.com"
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
      sock = TCPSocket.new domain, 4444
      sock.write({}.to_json)
      if IO.select([sock], nil, nil, 60)
        android.util.Log.v 'Punch', "got something?"
        result = sock.read
        puts result
        response = JSON.parse(result)
        remote_host, remote_port = response["host"].split(":")
        my_host, my_port = response["my_host"].split(":")
      else
        android.util.Log.v 'Punch', "timed out, returning"
        sock.close
        return
      end
      if remote_host == my_host
        puts "talking to ourself"
        sock.close
        return
      end
      request = Request.new response
      request.save
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
    @timeouts = 0

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
        i = 0
        @timeouts += 1
        if @timeouts > 10
          puts "actually timed out"
          udp_in.close
          return
        end
        if @start
          begin
            type = JSON.parse(response["data"])["type"]
            if type == "ls"
              Picture.get_latest
              json = Picture.last(10).to_json
              while (content = json.slice!(0, 1024)) != ""
                udp_in.send(content, 0, remote_host, remote_port)
              end
            else
              p = Picture.find(type.strip)#type)
              puts p.to_json({})
              p.send_data(udp_in, remote_host, remote_port)
            end
          rescue => e
            puts "failed to call method #{e}"
            udp_in.close
            return
          end
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
