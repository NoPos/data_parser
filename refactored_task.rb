require 'json'
require 'pry'
require 'date'
require 'minitest/autorun'

class User
  attr_reader :attributes
  attr_accessor :sessions

  USER_FIELDS = [:id, :first_name, :last_name, :age].freeze
  SESSION_FIELDS = [:user_id, :session_id, :browser, :time, :date].freeze
  USER_COLUMN = 'user'.freeze
  SESSION_COLUMN = 'session'.freeze

  def initialize(attributes:)
    @attributes = attributes
    @sessions = []
  end

  def full_name
    "#{attributes[:first_name]} #{attributes[:last_name]}"
  end
end

class FileParser
  attr_reader :input_filename, :output_filename

  def initialize(input_filename = 'data.txt', output_filename = 'result.json')
    @input_filename = input_filename
    @output_filename = output_filename
  end

  def work
    fill_users_and_sessions!

    report[:totalUsers] = users_objects.count

    all_uniq_sorted_browsers = all_sessions.map { |s| s[:browser] }.uniq.sort

    report[:uniqueBrowsersCount] = all_uniq_sorted_browsers.count

    report[:totalSessions] = all_sessions.count

    report[:allBrowsers] = all_uniq_sorted_browsers.map(&:upcase).join(',')

    # User statistics
    report[:usersStats] = {}

    users_objects.each do |user|
      collect_stats_from_users(report, user, :sessions_count)
      collect_stats_from_users(report, user, :total_time)
      collect_stats_from_users(report, user, :longest_session)
      collect_stats_from_users(report, user, :browsers)
      collect_stats_from_users(report, user, :used_ie)
      collect_stats_from_users(report, user, :always_used_chrome)
      collect_stats_from_users(report, user, :dates)
    end

    file_write_out!
  end

  private

  def fill_users_and_sessions!
    current_user = nil
    file_lines.each do |line|
      cols = line.split(',')
      case cols[0]
      when User::USER_COLUMN
        current_user = User.new(attributes: parse_lines(line, User::USER_FIELDS))
        users_objects << current_user
      when User::SESSION_COLUMN
        current_session = parse_lines(line, User::SESSION_FIELDS)
        all_sessions << current_session
        current_user.sessions << current_session
      else
        raise 'Non expected line'
      end
    end
  end

  def users_objects
    @users_objects ||= []
  end

  def all_sessions
    @all_sessions ||= []
  end

  def file_write_out!
    File.write(output_filename, "#{report.to_json}\n")
  end

  def report
    @report ||= {}
  end

  def file_lines
    @file_lines ||= File.read(input_filename).split("\n")
  end

  def parse_lines(line, fields)
    line_to_a = line.split(',')
    h = {}
    fields.each do |k|
      h[k] = line_to_a[fields.index(k) + 1]
    end
    h
  end

  def collect_stats_from_users(report, user, report_key)
    report_data = report_keys[report_key].call(user.sessions)
    report[:usersStats][user.full_name] ||= {}
    report[:usersStats][user.full_name].merge!(report_data)
  end

  def report_keys
    # us - user_sessions
    {
      # Collect user sessions count
      sessions_count:     ->(us) { { sessionsCount: us.count } },
      # Collect user's total time
      total_time:         ->(us) { { totalTime: us.map{ |s| s[:time].to_i }.sum.to_s + ' min.' } },
      # Select the longest user session
      longest_session:    ->(us) { { longestSession: us.map{ |s| s[:time].to_i }.max.to_s + ' min.' } },
      # User's browsers list
      browsers:           ->(us) { { browsers: us.map {|s| s[:browser].upcase }.sort.join(', ') } },
      # Check if user used IE
      used_ie:            ->(us) { { usedIE: us.map{|s| s[:browser]}.uniq.any? { |b| b.upcase =~ /INTERNET EXPLORER/ } } },
      # Check if user always used Chrome?
      always_used_chrome: ->(us) { { alwaysUsedChrome: us.map { |s| s[:browser] }.uniq.all? { |b| b.upcase =~ /CHROME/ } } },
      # Session dates in the reverse order in iso8601 format
      dates:              ->(us) { { dates: us.map {|s| Date.parse(s[:date]).iso8601 }.sort.reverse } }
    }
  end
end
