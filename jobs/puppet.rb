require "net/http"
require "uri"
require "json"

DASHBOARD_URI = "https://example.com"

PUPPET_AUTH = {
  'name' => 'USER',
  'password' => 'PASS'
}

def get_json (url, user=PUPPET_AUTH['name'], pass=PUPPET_AUTH['password'])
  uri = URI.parse(url)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true 
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new("/api/dashboard")
  request.basic_auth(user,pass)
  response = http.request(request)
  return JSON.parse(response.body)
end


SCHEDULER.every '60s', :first_in => 0 do |job|
  result = get_json(DASHBOARD_URI)

  data = Hash.new
  data[:nodes] = Hash.new
  data[:nodes][:total]        = result["total_hosts"]
  data[:nodes][:changed]      = result["active_hosts_ok"] 
  data[:nodes][:unchanged]    = result["ok_hosts"]
  data[:nodes][:unresponsive] = result["out_of_sync_hosts"]
  data[:nodes][:failed]       = result["bad_hosts"]
  data[:nodes][:pending]      = result["pending_hosts"]

  send_event('puppet', {
    total: "Total nodes served by puppet: #{data[:nodes][:total]}",
    changed: "Recently changed nodes: #{data[:nodes][:changed]}",
    unchanged: "Unchanged nodes: #{data[:nodes][:unchanged]}",
    unresponsive: "Unresponsive nodes: #{data[:nodes][:unresponsive]}",
    failed: "Recently failed nodes: #{data[:nodes][:failed]}",
    pending: "Currently pending nodes: #{data[:nodes][:pending]}",
    changed_i: data[:nodes][:changed],
    failed_i: data[:nodes][:failed],
    pending_i: data[:nodes][:pending]    
  })
end

