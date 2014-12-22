require 'net/http'
require 'json'
require 'time'

JENKINS__URI = URI.parse("http://example.com")

JENKINS__AUTH = {
  'name' => 'USER',
  'password' => 'PASS'
}

def get_global_build_stats()
  http = Net::HTTP.new(JENKINS__URI.host, JENKINS__URI.port)
  request = Net::HTTP::Get.new("/api/json?tree=jobs[builds[result]]")
  if JENKINS__AUTH['name']
    request.basic_auth(JENKINS__AUTH['name'], JENKINS__AUTH['password'])
  end
  response = http.request(request)
  build_result = {
  'SUCCESS' => response.body.scan(/SUCCESS/).size,
  'FAILURE' => response.body.scan(/FAILURE/).size
  }
  return build_result
end


SCHEDULER.every '5m', :first_in => 0 do |job|
  results = get_global_build_stats()
  results.each do |status, count|
    send_event( status , { current: count })
  end
end
