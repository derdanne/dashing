require 'net/http'
require 'json'
require 'time'

LIVELOGS_URI = URI.parse("http://example.com:12900")

LIVELOGS_AUTH = {
  'name' => 'USER',
  'password' => 'PASS'
}

DASHBOARD_IDS = {
  'NAME' => 'DASHBOARD_ID',
}

job_mapping = {
  'widget_name1' => { :widget_id => 'WIDGET_ID'},
  'widget_name2' => { :widget_id => 'WIDGET_ID'},
}

def get_json_widget(widget_id, dashboard_id=DASHBOARD_IDS['NAME'])
  http = Net::HTTP.new(LIVELOGS_URI.host, LIVELOGS_URI.port)
  request = Net::HTTP::Get.new("/dashboards/#{dashboard_id}/widgets/#{widget_id}/value")
  request.basic_auth(LIVELOGS_AUTH['name'], LIVELOGS_AUTH['password'])
  response = http.request(request)
  return JSON.parse(response.body)
end

job_mapping.each do |title, widget|
  current_status = nil 
  SCHEDULER.every '180s', :first_in => 0 do |job|
    last_status = current_status
    data = get_json_widget(widget[:widget_id])
    current_status = data["result"]
    send_event(title, {
      current: current_status, 
      last: last_status
    })
  end
end


