require 'sinatra/base'
require 'sinatra-websocket'
require 'thread'
require 'json/ext'

module Lysergide::RealtimePool
  @queue = Queue.new

  def self.queue
    @queue
  end

  def self.pop()
    @queue.pop
  end

  def self.push(i)
    LOG.info('Lysergide::RealtimePool') { "Pushed new #{i[:msg][:type]} event to queue" }
    @queue.push i
  end

  class << self
    alias_method '<<', :push
  end
end

class Lysergide::Realtime < Sinatra::Base
  set :wsockets, {}
  set :wthread, nil

  def sub(ws, s, args)
    if args.length != 1
      {type: :error, err: :a, msg: 'sub/1'}
    else
      s.wsockets[ws][:subs] << args[0]
      LOG.info('Lysergide::Realtime') { "WebSocket by #{s.wsockets[ws][:user]} subscribed to #{args[0]}" }
      {type: :success, msg: "+#{args[0]}"}
    end
  end

  def unsub(ws, s, args)
    if args.length != 1
      {type: :error, err: :a, msg: 'unsub/1'}
    else
      if s.wsockets[ws][:subs][args[0]]
        s.wsockets[ws][:subs].delete args[0]
        {type: :success, msg: "-#{args[0]}"}
      else
        {type: :error, err: :a, msg: "?#{args[0]}"}
      end
    end
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
      #when 'ping'  then ping  ws, s, args
      #when 'pong'  then pong  ws, s, args
      else
        LOG.warn('Lysergide::Realtime') { "Unknown command #{cmd} from #{s.wsockets[ws][:user]}" }
        {type: :error, err: :c, msg: 'unknown command'}
      end
    rescue StandardError => e
      LOG.error('Lysergide::Realtime') { "Error executing #{cmd}: #{e.message}" }
      {type: :error, err: :c, msg: 'malformed command'}
    end
  end

  get '/realtime' do
    if !request.websocket?
      halt 400, 'websocket-only endpoint'
    end
    if !session[:user]
      halt 400, 'authenticate first'
    end
    request.websocket do |ws|
      ws.onopen do
        LOG.info('Lysergide::Realtime') { "WebSocket opened by #{request.ip.to_s}" }
        ws.send({ver: 'lys-0.1'}.to_json)
        settings.wsockets.merge!({ws => {user: session[:user], subs: []}})
        if !settings.wthread
          settings.wthread = Thread.new do
            LOG.info('Lysergide::Realtime') { 'Worker started' }
            while true
              exit if Thread.current[:request_stop]
              if msg = Lysergide::RealtimePool.pop
                LOG.info('Lysergide::Realtime') { "Dispatching #{msg.inspect}" }
                settings.wsockets.each do |s, d|
                  LOG.debug('Lysergide::Realtime') { "Iterating over WebSocket by #{d[:user]}" }
                  LOG.debug('Lysergide::Realtime') { "User: #{msg[:users].include? d[:user]}" }
                  LOG.debug('Lysergide::Realtime') { "Subs: #{!(d[:subs] & msg[:subs]).empty?}" }
                  if msg[:users].include?(d[:user]) && !(d[:subs] & msg[:subs]).empty?
                    LOG.debug('Lysergide::Realtime') { "WebSocket by #{d[:user]} eligible, forwarding" }
                    s.send({type: :msg, subs: d[:subs] & msg[:subs], msg: msg[:msg]}.to_json)
                  end
                end
              else
                sleep 1
              end
              settings.wsockets.each do |s, d|
                s.send({type: :keepalive}.to_json)
              end
            end
          end
        end
      end
      ws.onclose do
        LOG.info('Lysergide::Realtime') { "WebSocket closed by #{request.ip.to_s}" }
        settings.wsockets.delete ws
      end
      ws.onmessage do |msg|
        ws.send process(ws, settings, msg).to_json
      end
    end
  end
end
