require "json"

ENV["PATH"] = "/opt/homebrew/bin:#{ENV["PATH"]}"

repos_json = `gh repo list --limit 10 --json name,nameWithOwner,description`
repos = JSON.parse(repos_json)

items = repos.map do |repo|
  {
    title: repo["name"],
    subtitle: repo["description"],
    arg: repo["nameWithOwner"]
  }
end

puts JSON.generate({ items: items })
