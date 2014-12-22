require 'net/http'
require 'json'
require 'time'

JENKINS_URI = URI.parse("http://example.com")

JENKINS_AUTH = {
  'name' => 'USER',
  'password' => 'PASS'
}


job_mapping = {
  'job1' => { :job => 'job-name1'},
  'job2' => { :job => 'job-name2'},
}

def get_number_of_failing_tests(job_name)
  info = get_json_for_job(job_name, 'lastCompletedBuild')
  info['actions'][4]['failCount']
end

def get_completion_percentage(job_name)
  build_info = get_json_for_job(job_name)
  prev_build_info = get_json_for_job(job_name, 'lastCompletedBuild')

  return 0 if not build_info["building"]
  last_duration = (prev_build_info["duration"] / 1000).round(2)
  current_duration = (Time.now.to_f - build_info["timestamp"] / 1000).round(2)
  return 99 if current_duration >= last_duration
  ((current_duration * 100) / last_duration).round(0)
end

def get_json_for_job(job_name, build = 'lastBuild')
  job_name = URI.encode(job_name)
  http = Net::HTTP.new(JENKINS_URI.host, JENKINS_URI.port)
  request = Net::HTTP::Get.new("/job/#{job_name}/#{build}/api/json")
  # http.use_ssl = true
  # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  if JENKINS_AUTH['name']
    request.basic_auth(JENKINS_AUTH['name'], JENKINS_AUTH['password'])
  end
  response = http.request(request)
  JSON.parse(response.body)
end

def get_complete_json_for_job(job_name)
  job_name = URI.encode(job_name)
  http = Net::HTTP.new(JENKINS_URI.host, JENKINS_URI.port)
  request = Net::HTTP::Get.new("/job/#{job_name}/api/json")
  if JENKINS_AUTH['name']
    request.basic_auth(JENKINS_AUTH['name'], JENKINS_AUTH['password'])
  end
  response = http.request(request)
  JSON.parse(response.body)
end

job_mapping.each do |title, jenkins_project|
  current_status = nil
  SCHEDULER.every '60s', :first_in => 0 do |job|
    last_status = current_status
    build_info = get_json_for_job(jenkins_project[:job])
    current_status = build_info["result"]
    if build_info["building"]
      current_status = "BUILDING"
      percent = get_completion_percentage(jenkins_project[:job])
    elsif jenkins_project[:pre_job]
      pre_build_info = get_json_for_job(jenkins_project[:pre_job])
      current_status = "PREBUILD" if pre_build_info["building"]
      percent = get_completion_percentage(jenkins_project[:pre_job])
    end
    build_info_complete = get_complete_json_for_job(jenkins_project[:job])
    build_stability = build_info_complete.fetch("healthReport").first.fetch("description")
    build_stability_percentage = build_info_complete.fetch("healthReport").first.fetch("score").to_i 
    build_count = "Number of builds: #{build_info_complete.fetch("builds").first.fetch("number")}"

    send_event(title, {
      currentResult: current_status,
      lastBuilt: "Last Build: #{current_status}!",
      lastResult: last_status,
      timestamp: build_info["timestamp"],
      health: build_stability,
      health_p: build_stability_percentage,
      buildcount: build_count,
      value: percent
    })
  end
end


