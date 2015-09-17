require 'sinatra/base'
require 'sinatra-websocket'
require 'thread'
require 'json/ext'
require 'lysergide/database'

module Lysergide
  module RealtimePool
    @queue = Queue.new

    def self.queue
      @queue
    end

    def self.pop
      begin
        @queue.pop true
      rescue
        nil
      end
    end

    def self.push(i)
      LOG.info('Lysergide::RealtimePool') { "New #{i[:msg][:type]} event queued" }
      @queue.push i
    end

    class << self
      alias_method '<<', :push
    end
  end
end

module Lysergide
  class Realtime < Sinatra::Base
    set :wsockets, {}
    set :wthread, nil

    def sub(ws, s, args)
      return { type: :error, err: :a, msg: 'sub/1' } if args.length < 1
      type = args.shift
      if s.wsockets[ws][:subs]
        new_subs = [args]
        new_subs.concat s.wsockets[ws][:subs][type] if s.wsockets[ws][:subs][type]
        s.wsockets[ws][:subs].merge!({ type => new_subs.length == 1 ? true : new_subs })
      end
      LOG.info('Lysergide::Realtime') { "WebSocket by #{s.wsockets[ws][:user]} subscribed to #{type}[#{args.join ', '}]" }
      { type: :success, msg: "+#{type}" }
    end

    def unsub(ws, s, args)
      return { type: :error, err: :a, msg: 'unsub/1' } if args.length < 1
      type = args.shift
      if s.wsockets[ws][:subs][type]
        if args.length == 0
          s.wsockets[ws][:subs].delete type
        else
          s.wsockets[ws][:subs][type].delete args
        end
        { type: :success, msg: "-#{type}" }
      else
        { type: :error, err: :a, msg: "?#{type}" }
      end
    end

    def repo_set(ws, s, args)
      return { type: :error, err: :a, msg: 'repo_set/3' } if args.length < 3
      repo = User.find(s.wsockets[ws][:user]).repos.find_by_name(args.shift)
      case args.shift
      when 'public' then repo.public = %(true 1 yes t).include? args.shift
      else
        return { type: :error, err: :a, msg: '?' }
      end
      repo.save
      { type: :success, msg: 'repo_updated' }
    end

    def process(ws, s, msg)
      begin
        # cmd args...
        args = msg.split ' '
        cmd  = args.shift
        LOG.info('Lysergide::Realtime') { "WebSocket by #{s.wsockets[ws][:user]} issued #{cmd} command" }
        case cmd
        when 'sub'   then sub   ws, s, args
        when 'unsub' then unsub ws, s, args
        # when 'ping'  then ping  ws, s, args
        # when 'pong'  then pong  ws, s, args
        when 'repo_set' then repo_set ws, s, args
        else
          LOG.warn('Lysergide::Realtime') { "Unknown command #{cmd} from #{s.wsockets[ws][:user]}" }
          { type: :error, err: :c, msg: 'unknown command' }
        end
      rescue StandardError => e
        LOG.error('Lysergide::Realtime') { "Error executing #{cmd}: #{e.message}" }
        { type: :error, err: :c, msg: 'malformed command' }
      end
    end

    get '/realtime' do
      halt 400, 'websocket-only endpoint' unless request.websocket?
      halt 400, 'authenticate first' unless session[:user]
      request.websocket do |ws|
        ws.onopen do
          LOG.info('Lysergide::Realtime') { "WebSocket opened by #{request.ip}" }
          ws.send({ ver: 'lys-0.1' }.to_json)
          settings.wsockets.merge!(
            ws => {
              user: session[:user],
              subs: {}
            }
          )
          unless settings.wthread
            settings.wthread = Thread.new do
              LOG.info('Lysergide::Realtime') { 'Worker started' }
              loop do
                exit if Thread.current[:request_stop]
                if msg = Lysergide::RealtimePool.pop
                  LOG.info('Lysergide::Realtime') { "Dispatching #{msg.inspect}" }
                  settings.wsockets.each do |s, d|
                    LOG.debug('Lysergide::Realtime') { "Iterating over WebSocket by #{d[:user]}" }
                    LOG.debug('Lysergide::Realtime') { "User: #{msg[:users].include? d[:user]}" }
                    LOG.debug('Lysergide::Realtime') { "Subs: #{!(d[:subs].to_a.flatten & msg[:subs]).empty?}" }
                    if msg[:users].include?(d[:user]) && !(d[:subs].to_a.flatten & msg[:subs]).empty?
                      LOG.debug('Lysergide::Realtime') { "WebSocket by #{d[:user]} eligible, forwarding" }
                      s.send({ type: :msg, subs: d[:subs].to_a.flatten & msg[:subs], msg: msg[:msg] }.to_json)
                    end
                  end
                else
                  sleep 10
                end
                if settings.wsockets.length > 0
                  LOG.debug('Lysergide::Realtime') { 'Sending keepalive' }
                  keepalive_count = 0
                  settings.wsockets.each do |s, _d|
                    s.send({ type: :keepalive }.to_json)
                    keepalive_count += 1
                  end
                  LOG.debug('Lysergide::Realtime') { "Sent #{keepalive_count} keepalive#{keepalive_count == 1 ? '' : 's'}" }
                end
              end
            end
          end
        end
        ws.onclose do
          LOG.info('Lysergide::Realtime') { "WebSocket closed by #{request.ip}" }
          settings.wsockets.delete ws
        end
        ws.onmessage do |msg|
          ws.send process(ws, settings, msg).to_json
        end
      end
    end
  end
end
