ENV["PATH"] = "/opt/homebrew/bin:#{ENV["PATH"]}"

repo = ARGV[0]

system("gh", "repo", "view", repo, "--web")
