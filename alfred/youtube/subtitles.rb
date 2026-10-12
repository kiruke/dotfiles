#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "time"
require "uri"

ENV["PATH"] = ["/opt/homebrew/bin", "/usr/local/bin", ENV["PATH"]].compact.join(File::PATH_SEPARATOR)

module YouTubeSubtitles
  class WorkflowError < StandardError; end

  class SourcePreservationError < StandardError
    attr_reader :source_dir

    def initialize(message, source_dir)
      super(message)
      @source_dir = source_dir
    end
  end

  def self.run(url)
    work_dir = nil
    keep_work_dir = false

    begin
      validate_url!(url)

      yt_dlp = executable_path("yt-dlp")
      zip = executable_path("zip")
      unzip = executable_path("unzip")
      downloads = File.expand_path("~/Downloads")
      raise WorkflowError, "Downloadsフォルダが見つかりません: #{downloads}" unless Dir.exist?(downloads)

      work_dir = Dir.mktmpdir("youtube-subtitles-")
      playlist = load_playlist(yt_dlp, url)
      entries = Array(playlist["entries"]).compact
      raise WorkflowError, "再生リストに動画がありません。" if entries.empty?

      subtitles = []
      failures = []

      entries.each_with_index do |entry, index|
        title = entry["title"].to_s.strip
        title = "タイトル不明" if title.empty?
        video_url = video_url_for(entry)

        if video_url.empty?
          failures << { title: title, url: "不明", reason: "動画URLを取得できませんでした。" }
          next
        end

        item_dir = File.join(work_dir, format("%04d", index + 1))
        FileUtils.mkdir_p(item_dir)
        output_template = File.join(item_dir, "%(id)s.%(ext)s")
        stdout, stderr, status = Open3.capture3(
          yt_dlp,
          "--skip-download",
          "--write-auto-subs",
          "--sub-langs", "ja",
          "--sub-format", "vtt",
          "--no-warnings",
          "--no-playlist",
          "--output", output_template,
          video_url
        )

        vtt_files = Dir.glob(File.join(item_dir, "**", "*.vtt")).sort
        vtt_files.each do |vtt_file|
          destination = File.join(work_dir, format("%04d-%s", index + 1, File.basename(vtt_file)))
          FileUtils.cp(vtt_file, destination)
          subtitles << destination
        end

        if !status.success?
          failures << { title: title, url: video_url, reason: command_error(stdout, stderr) }
        elsif vtt_files.empty?
          failures << { title: title, url: video_url, reason: "日本語の自動字幕が見つかりませんでした。" }
        end
      rescue StandardError => e
        failures << { title: title, url: video_url, reason: e.message }
      end

      publish_results(downloads, work_dir, subtitles, failures, zip, unzip)
    rescue SourcePreservationError => e
      keep_work_dir = true
      notify("ZIP作成失敗・字幕を保持", "元字幕は一時フォルダに保持されています: #{e.source_dir}")
      warn "#{e.message} 元字幕: #{e.source_dir}"
      1
    end
  rescue WorkflowError => e
    notify("YouTube字幕収集に失敗", e.message)
    warn e.message
    1
  rescue StandardError => e
    notify("YouTube字幕収集に失敗", e.message)
    warn "処理に失敗しました: #{e.message}"
    1
  ensure
    FileUtils.rm_rf(work_dir) if work_dir && !keep_work_dir && Dir.exist?(work_dir)
  end

  def self.load_playlist(yt_dlp, url)
    stdout, stderr, status = Open3.capture3(
      yt_dlp,
      "--flat-playlist",
      "--dump-single-json",
      "--no-warnings",
      url
    )
    raise WorkflowError, "再生リストを読み込めませんでした: #{command_error(stdout, stderr)}" unless status.success?

    JSON.parse(stdout)
  rescue JSON::ParserError => e
    raise WorkflowError, "yt-dlpの再生リスト情報を解析できませんでした: #{e.message}"
  end

  def self.validate_url!(url)
    raise WorkflowError, "再生リストURLを指定してください。" if url.to_s.strip.empty?

    uri = URI.parse(url)
    allowed_hosts = %w[youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be]
    unless %w[http https].include?(uri.scheme) && allowed_hosts.include?(uri.host)
      raise WorkflowError, "YouTubeの再生リストURLを指定してください。"
    end
  rescue URI::InvalidURIError
    raise WorkflowError, "URLの形式が正しくありません。"
  end

  def self.video_url_for(entry)
    url = entry["url"].to_s
    return url if url.match?(%r{\Ahttps?://})

    id = entry["id"].to_s
    return "" if id.empty?

    "https://www.youtube.com/watch?v=#{id}"
  end

  def self.publish_results(downloads, work_dir, subtitles, failures, zip, unzip)
    base = unique_base_name(downloads)
    staging_dir = Dir.mktmpdir(".youtube-subtitles-", downloads)
    zip_path = nil
    report_path = nil

    unless subtitles.empty?
      staged_zip = File.join(staging_dir, "subtitles.zip")
      begin
        _stdout, stderr, status = Open3.capture3(zip, "-q", "-j", staged_zip, *subtitles)
        raise WorkflowError, "ZIPを作成できませんでした: #{stderr.strip}" unless status.success?

        _stdout, stderr, status = Open3.capture3(unzip, "-tq", staged_zip)
        raise WorkflowError, "ZIPの整合性検証に失敗しました: #{stderr.strip}" unless status.success?

        zip_path = File.join(downloads, "#{base}.zip")
        File.rename(staged_zip, zip_path)
      rescue StandardError => zip_error
        begin
          retained_dir = preserve_source_files(downloads, subtitles, failures, zip_error.message)
        rescue StandardError => preservation_error
          raise SourcePreservationError.new(
            "ZIP処理に失敗し、Downloadsへの退避もできませんでした: #{preservation_error.message}",
            work_dir
          )
        end
        raise WorkflowError, "#{zip_error.message} 元のVTTは保持しました: #{retained_dir}"
      end
    end

    unless failures.empty?
      staged_report = File.join(staging_dir, "failures.txt")
      File.write(staged_report, failure_report(failures), encoding: "UTF-8")
      report_path = File.join(downloads, "#{base}-failures.txt")
      File.rename(staged_report, report_path)
    end

    FileUtils.rm_rf(staging_dir)

    if subtitles.empty?
      message = "字幕を取得できる動画がありません。失敗一覧: #{report_path || "作成できませんでした"}"
      notify("YouTube字幕収集完了", message)
      puts message
      return 1
    end

    message = "字幕ファイル #{subtitles.length} 件を保存しました: #{zip_path}"
    message += " / 失敗 #{failures.length} 件: #{report_path}" unless failures.empty?
    notify("YouTube字幕収集完了", message)
    puts message
    0
  ensure
    FileUtils.rm_rf(staging_dir) if staging_dir && Dir.exist?(staging_dir)
  end

  def self.failure_report(failures)
    lines = ["YouTube字幕取得の失敗一覧", "作成日時: #{Time.now.iso8601}", "失敗件数: #{failures.length}", ""]
    failures.each_with_index do |failure, index|
      lines << "#{index + 1}. #{failure[:title]}"
      lines << "   URL: #{failure[:url]}"
      lines << "   理由: #{failure[:reason]}"
    end
    lines.join("\n") + "\n"
  end

  def self.preserve_source_files(downloads, subtitles, failures, zip_error)
    staging_dir = Dir.mktmpdir(".youtube-subtitles-preserved-", downloads)
    content_dir = File.join(staging_dir, "vtt")
    FileUtils.mkdir_p(content_dir)
    subtitles.each { |subtitle| FileUtils.cp(subtitle, File.join(content_dir, File.basename(subtitle))) }

    preservation_failures = failures + [{ title: "ZIP作成・検証", url: "-", reason: zip_error }]
    File.write(File.join(staging_dir, "failures.txt"), failure_report(preservation_failures), encoding: "UTF-8")

    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    destination = File.join(downloads, "youtube-subtitles-zip-failed-#{timestamp}")
    suffix = 1
    while File.exist?(destination)
      destination = File.join(downloads, "youtube-subtitles-zip-failed-#{timestamp}-#{suffix}")
      suffix += 1
    end
    File.rename(staging_dir, destination)
    staging_dir = nil
    destination
  ensure
    FileUtils.rm_rf(staging_dir) if staging_dir && Dir.exist?(staging_dir)
  end

  def self.unique_base_name(directory)
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    base = "youtube-subtitles-#{timestamp}"
    suffix = 1
    while File.exist?(File.join(directory, "#{base}.zip")) || File.exist?(File.join(directory, "#{base}-failures.txt"))
      base = "youtube-subtitles-#{timestamp}-#{suffix}"
      suffix += 1
    end
    base
  end

  def self.executable_path(command)
    path = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).find do |directory|
      candidate = File.join(directory, command)
      File.file?(candidate) && File.executable?(candidate)
    end
    raise WorkflowError, "#{command}が見つかりません。PATHを確認してください。" unless path

    File.join(path, command)
  end

  def self.command_error(stdout, stderr)
    detail = [stderr, stdout].join("\n").lines.map(&:strip).reject(&:empty?).last(5).join(" | ")
    detail = "詳細ログはありません。" if detail.empty?
    detail.length > 500 ? "#{detail[0, 497]}..." : detail
  end

  def self.notify(title, message)
    escape = ->(text) { text.to_s.gsub("\\", "\\\\").gsub('"', '\\"').gsub(/[\r\n]/, " ") }
    script = "display notification \"#{escape.call(message)}\" with title \"#{escape.call(title)}\""
    Open3.capture3("/usr/bin/osascript", "-e", script)
  rescue StandardError
    nil
  end
end

exit YouTubeSubtitles.run(ARGV[0]) if $PROGRAM_NAME == __FILE__