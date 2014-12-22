require 'net/http'
require 'json'
require 'time'

ICINGA_URI = URI.parse("http://example.com")

ICINGA_AUTH = {
  'name' => 'USER',
  'password' => 'PASSWORD'
}


def get_complete_json_for_unhandled_checks()
  http = Net::HTTP.new(ICINGA_URI.host, ICINGA_URI.port)
  request = Net::HTTP::Get.new("/icinga/cgi-bin/status.cgi?allunhandledproblems&jsonoutput")
  if ICINGA_AUTH['name']
    request.basic_auth(ICINGA_AUTH['name'], ICINGA_AUTH['password'])
  end
  response = http.request(request)
  return JSON.parse(response.body)
end

def get_complete_json_for_hosts()
  http = Net::HTTP.new(ICINGA_URI.host, ICINGA_URI.port)
  request = Net::HTTP::Get.new("/icinga/cgi-bin/status.cgi?host=all&style=hostdetail&hoststatustypes=2&jsonoutput")
  if ICINGA_AUTH['name']
    request.basic_auth(ICINGA_AUTH['name'], ICINGA_AUTH['password'])
  end
  response = http.request(request)
  hostcount = response.body.scan(/host_name/).size
  return hostcount
end

def get_complete_json_for_services()
  http = Net::HTTP.new(ICINGA_URI.host, ICINGA_URI.port)
  request = Net::HTTP::Get.new("/icinga/cgi-bin/status.cgi?host=all&style=detail&servicestatustypes=2&jsonoutput")
  if ICINGA_AUTH['name']
    request.basic_auth(ICINGA_AUTH['name'], ICINGA_AUTH['password'])
  end
  response = http.request(request)
  servicecount = response.body.scan(/host_name/).size
  return servicecount
end

SCHEDULER.every '30s', :first_in => 0 do |job|
  host_message = ""
  service_message = ""
  hostcount_warn = 0
  hostcount_crit = 0
  servicecount_warn = 0
  servicecount_crit = 0
  hostcount = get_complete_json_for_hosts()
  servicecount = get_complete_json_for_services()
 
  complete_status_info = get_complete_json_for_unhandled_checks()
  if !complete_status_info["status"]["host_status"].nil?
    complete_status_info["status"]["host_status"].each do |server|
      if server["status"].eql? "DOWN"
        hostcount_crit += 1
      else
        hostcount_warn += 1
      end
      host_message = "#{host_message}<p><h3 class=\"icinga-h3\">Host: <font color=\"black\">#{server["host_name"]}</font> has status <font color=\"black\">#{server["status"]}</font> since #{server["duration"]}. Message: #{server["status_information"]}</h3><br/></p>"
    end
  end
  if hostcount_crit == 0 and hostcount_warn == 0
     host_message = "<h2 class=\"value\">All hosts are up and alive!</h2>"
  end
  if !complete_status_info["status"]["service_status"].nil?
    complete_status_info["status"]["service_status"].each do |service|
      if service["status"].eql? "CRITICAL"
        servicecount_crit += 1
      else
        servicecount_warn += 1
      end
      service_message = "#{service_message}<p><h3 class=\"icinga-h3\">Service: <font color=\"black\">#{service["service_description"]}</font> on host <font color=\"black\">#{service["host_name"]}</font> has status <font color=\"black\">#{service["status"]}</font> since #{service["duration"]}. Message: #{service["status_information"]}</h3><br/></p>"
    end
  end
  if servicecount_crit == 0 and servicecount_warn == 0
    service_message = "<h2 class=\"value\">All services are alive!</h2>"
  end
  hostcount += hostcount_crit + hostcount_warn
  servicecount += servicecount_crit + servicecount_warn
  send_event('icinga-hosts', {
    hostCount: "Observing #{hostcount} hosts",
    hostMessage: host_message,
    hostCountWarn: hostcount_warn,
    hostCountCrit: hostcount_crit
  })
  send_event('icinga-services', {
    serviceCount: "Observing #{servicecount} services",
    serviceMessage: service_message,
    serviceCountWarn: servicecount_warn,
    serviceCountCrit: servicecount_crit
  })
end


