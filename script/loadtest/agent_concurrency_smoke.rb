#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'socket'
require 'securerandom'
require 'optparse'

class Client
  def initialize(base_url)
    @base_url = base_url.chomp('/')
  end

  def register(join_token, name)
    post('/api/v1/agents/register', {
      join_token: join_token,
      agent: {
        name: name,
        hostname: Socket.gethostname,
        host_uid: SecureRandom.uuid,
        platform: RUBY_PLATFORM,
        version: 'loadtest',
        tags: ['loadtest'],
        metadata: { scenario: 'agent_concurrency_smoke' }
      }
    })
  end

  def heartbeat(agent_id, token)
    post("/api/v1/agents/#{agent_id}/heartbeat", { status: 'online' }, token: token)
  end

  def next_task(token)
    get('/api/v1/tasks/next', token: token)
  end

  def complete_task(task_id, token, output)
    patch("/api/v1/tasks/#{task_id}/complete", { task: { output: output } }, token: token)
  end

  private

  def get(path, token: nil)
    request(Net::HTTP::Get.new(uri(path)), token)
  end

  def post(path, body, token: nil)
    req = Net::HTTP::Post.new(uri(path), 'Content-Type' => 'application/json')
    req.body = JSON.dump(body)
    request(req, token)
  end

  def patch(path, body, token: nil)
    req = Net::HTTP::Patch.new(uri(path), 'Content-Type' => 'application/json')
    req.body = JSON.dump(body)
    request(req, token)
  end

  def request(req, token)
    req['Authorization'] = "Bearer #{token}" if token
    uri = req.uri
    http = Net::HTTP.new(uri.host, uri.port)
    res = http.request(req)
    body = res.body.to_s
    parsed = body.empty? ? nil : JSON.parse(body)
    [res.code.to_i, parsed, body]
  end

  def uri(path)
    URI.parse("#{@base_url}#{path}")
  end
end

options = {
  base_url: ENV.fetch('CLAWDECK_BASE_URL', 'http://localhost:3000'),
  join_tokens: (ENV['CLAWDECK_JOIN_TOKENS'] || '').split(',').map(&:strip).reject(&:empty?),
  agents: (ENV['LOADTEST_AGENTS'] || 4).to_i,
  iterations: (ENV['LOADTEST_ITERATIONS'] || 10).to_i
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby script/loadtest/agent_concurrency_smoke.rb --join-token TOKEN [--join-token TOKEN ...] [options]'
  opts.on('--base-url URL') { |v| options[:base_url] = v }
  opts.on('--join-token TOKEN') { |v| options[:join_tokens] << v }
  opts.on('--agents N', Integer) { |v| options[:agents] = v }
  opts.on('--iterations N', Integer) { |v| options[:iterations] = v }
end.parse!

abort 'need one join token per agent via repeated --join-token or CLAWDECK_JOIN_TOKENS' if options[:join_tokens].empty?
abort "need at least #{options[:agents]} join tokens for #{options[:agents]} agents" if options[:join_tokens].length < options[:agents]

client = Client.new(options[:base_url])
agents = []

options[:agents].times do |i|
  code, body, raw = client.register(options[:join_tokens][i], "load-agent-#{i + 1}")
  abort "register failed: #{code} #{raw}" unless code == 201

  agents << {
    id: body.fetch('agent').fetch('id'),
    token: body.fetch('agent_token'),
    name: body.fetch('agent').fetch('name')
  }
end

claimed = Hash.new(0)
completed = Hash.new(0)
empty_polls = 0
mutex = Mutex.new
threads = []

agents.each do |agent|
  threads << Thread.new do
    options[:iterations].times do |iteration|
      hb_code, = client.heartbeat(agent[:id], agent[:token])
      raise "heartbeat failed for #{agent[:name]}: #{hb_code}" unless hb_code == 200

      code, body, raw = client.next_task(agent[:token])
      case code
      when 200
        task_id = body.fetch('id')
        mutex.synchronize { claimed[task_id] += 1 }
        sleep(rand * 0.2)
        complete_code, = client.complete_task(task_id, agent[:token], "completed by #{agent[:name]} iteration #{iteration + 1}")
        raise "complete failed for task #{task_id}: #{complete_code}" unless complete_code == 200
        mutex.synchronize { completed[task_id] += 1 }
      when 204
        mutex.synchronize { empty_polls += 1 }
        sleep(0.1)
      else
        raise "next_task failed for #{agent[:name]}: #{code} #{raw}"
      end
    end
  end
end

threads.each(&:join)

duplicates = claimed.select { |_task_id, count| count > 1 }

puts JSON.pretty_generate({
  agents: agents.size,
  iterations_per_agent: options[:iterations],
  unique_tasks_claimed: claimed.keys.size,
  total_claim_events: claimed.values.sum,
  total_completions: completed.values.sum,
  empty_polls: empty_polls,
  duplicate_claims: duplicates
})

if duplicates.any?
  abort 'duplicate claims detected'
end
