require 'rubygems'
require 'uri'
require 'tinder'
require 'buffet/settings'

module Campfire
  CAMPFIRE_SETTINGS = ::Buffet::Settings.get["campfire"]
  SUBDOMAIN = CAMPFIRE_SETTINGS["subdomain"]
  ROOM_NAME = CAMPFIRE_SETTINGS["room_name"]
  USERNAME  = CAMPFIRE_SETTINGS["username"]
  PASSWORD  = CAMPFIRE_SETTINGS["password"]

  def self.connect_and_login(user=USERNAME, pass=PASSWORD)
    Tinder::Campfire.new(
      SUBDOMAIN,
      :ssl => true,
      :username => user,
      :password => pass
    )

  rescue Tinder::AuthenticationFailed
    puts "Campfire username or password not valid."
  end

  def self.campfire
    @campfire ||= connect_and_login
  end

  def self.room
    @room ||= campfire.find_room_by_name(ROOM_NAME)
  end

  def self.speak(message)
    room.speak(message)
  end

  def self.paste(message)
    room.paste(message)
  end
end
