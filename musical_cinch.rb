#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "cinch"
require "librmpd"

module MusicalCinch
  class MpdPlugin
    include Cinch::Plugin

    timer 1, method: :update_status

    attr_reader :current_song, :state

    def update_status
      new_state = bot.config.mpd_client.status["state"]
      new_current_song = bot.config.mpd_client.current_song

      if @state.nil? || @state != new_state || @current_song != new_current_song
        if new_current_song
          text = "[#{new_state}] #{new_current_song["artist"]} ~ #{new_current_song["title"]}"
        elsif @state == "stop"
          text = "[playlist finished]"
        end
        bot.channels.each { |c| c.send(text) }
      end

      @current_song = new_current_song
      @state = new_state
    end
  end

  def self.run!(options)
    @bot = Cinch::Bot.new do
      configure do |c|
        c.server = options[:server]
        c.channels = options[:channels]
        c.nick = options[:nick]
        c.verbose = options[:verbose]
        c.plugins.plugins = [MpdPlugin]

        c.mpd_client = MPD.new(options[:mpd_host], options[:mpd_port])
        c.mpd_client.connect
      end

      on :join do |m|
        m.channel.msg "Sup"
      end

      on :message, /hola capo/i do |m|
        m.reply "viva peron #{m.user.nick}"
      end

      on :message, /que suena/i do |m|
        current_song = m.bot.plugins.find { |p| p.is_a?(MpdPlugin) }.current_song
        if current_song
          m.reply "#{m.user.nick}, suena #{current_song["artist"]} ~ #{current_song["title"]}"
        else
          m.reply "No está sonando nada #{m.user.nick} capo, no escuchás?"
        end
      end
    end

    @bot.start
  end
end


options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Output more information') do
    options[:verbose] = true
  end

  opts.on('-s', '--server HOST', 'IRC server, e.g. "irc.freenode.org"') do |host|
    options[:server] = host
  end

  opts.on('-c', '--channels a,b,c', 'List of IRC channels to connect (separated by comma)') do |channels|
    options[:channels] = Array(channels).map { |channel| "##{channel}" }
  end

  # Optionals
  options[:nick] = "musical_cinch"
  opts.on('-n', '--nick NAME', 'Override nickname (default "musical_cinch")') do |nick|
    options[:nick] = nick
  end
 
  options[:mpd_host] = "localhost"
  opts.on('--mpd-host HOST', 'MPD server host (default "localhost")') do |host|
    options[:mpd_host] = host
  end
 
  options[:mpd_port] = 6600
  opts.on('--mpd-port PORT', 'MPD server port (default 6600)') do |port|
    options[:mpd_port] = port
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!

if options[:server].nil? || options[:channels].empty?
  puts optparse
else
  MusicalCinch.run!(options)
end

