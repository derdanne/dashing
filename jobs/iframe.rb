SCHEDULER.every '600s', :first_in => 0 do |job|
    url = "http://example.com/#/dashboard/db/sitespeed-overall-dashboard?panelId=3&fullscreen"
    puts url
    send_event('sitespeed', url: url)
end
