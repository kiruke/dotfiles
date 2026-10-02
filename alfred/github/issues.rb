require "json"

query = ARGV[0].to_s.downcase

json = `/opt/homebrew/bin/gh search issues --owner kiruke --state open --json number,title,url,state,repository`
issues = JSON.parse(json)

filtered_issues = issues.select do |issue|
  issue["title"].downcase.include?(query)
end

items = filtered_issues.map do |issue|
  {
    title: "##{issue["number"]} #{issue["title"]}",
    subtitle: "#{issue["repository"]["nameWithOwner"]} • #{issue["state"]}",
    arg: issue["url"]
  }
end

puts JSON.generate({ items: items })
