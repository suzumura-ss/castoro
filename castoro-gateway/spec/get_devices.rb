#
# interface device check 
# return Array [[deviceName, ipAddr, bcastAddr],... ]
#
def getDevices
  devs = `/sbin/ifconfig -a`  
  devices = devs.split(/\n\n/).map {|device|
    if device =~ /BROADCAST/ && device =~ /MULTICAST/ && device =~ /RUNNING/ then
      devName = device.split()[0]
      addr = device.slice(/inet addr:(\d+\.\d+\.\d+\.\d+)/).split(/:/)[1]
      bcast = device.slice(/Bcast:(\d+\.\d+\.\d+\.\d+)/).split(/:/)[1]     
      [devName, addr, bcast]
    else
      nil
    end
  } 
  devices.compact!
end
   

