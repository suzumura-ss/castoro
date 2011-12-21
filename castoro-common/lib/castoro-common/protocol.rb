#
#   Copyright 2010 Ricoh Company, Ltd.
#
#   This file is part of Castoro.
#
#   Castoro is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Lesser General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Castoro is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public License
#   along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
#

require "castoro-common"

module Castoro
  class ProtocolError < CastoroError; end

  ALLOW_VERSIONS = ["1.1"]

  class Protocol

    def self.parse values
      begin
        values = JSON.parse(values) if values.kind_of? String
      rescue JSON::ParserError
        raise "Protocol parse error - Illegal JSON format."
      end
      
      raise ProtocolError, "Protocol parse error." unless values.kind_of? Array
      raise ProtocolError, "Protocol parse error." unless values.length == 4

      raise "Protocol parse error." unless values[0].kind_of? String
      raise "Protocol parse error." unless values[1].kind_of? String
      raise "Protocol parse error." unless values[2].kind_of? String
      raise "Protocol parse error." unless values[3].kind_of? Hash
      
      version, direction, opecode, operand = values
      raise "Protocol parse error - unsupported version." unless ALLOW_VERSIONS.include?(version)

      case direction
      when "C"
        Protocol::Command.parse(opecode, operand)
      when "R"
        Protocol::Response.parse(opecode, operand)
      else
        raise "Protocol parse error - unsupported direction."
      end

    rescue RuntimeError => e
      raise ProtocolError, e.message
    end

    def == other
      return false unless self.class == other.class
      self.to_s == other.to_s
    end
  end

  class Protocol::Command < Protocol
    def self.parse opecode, operand

      case opecode
      when "NOP"
        Protocol::Command::Nop.new()
      when "CREATE"
        Protocol::Command::Create.new(operand["basket"], operand["hints"])
      when "FINALIZE"
        Protocol::Command::Finalize.new(operand["basket"], operand["host"], operand["path"])
      when "CANCEL"
        Protocol::Command::Cancel.new(operand["basket"], operand["host"], operand["path"])
      when "GET"
        Protocol::Command::Get.new(operand["basket"], operand["island"])
      when "DELETE"
        Protocol::Command::Delete.new(operand["basket"])
      when "INSERT"
        Protocol::Command::Insert.new(operand["basket"], operand["host"], operand["path"])
      when "DROP"
        Protocol::Command::Drop.new(operand["basket"], operand["host"], operand["path"])
      when "ALIVE"
        Protocol::Command::Alive.new(operand["host"], operand["status"], operand["available"])
      when "ISLAND"
        Protocol::Command::Island.new(operand["island"], operand["storables"], operand["capacity"])
      when "STATUS"
        Protocol::Command::Status.new()
      when "DUMP"
        Protocol::Command::Dump.new()
      when "MKDIR"
        Protocol::Command::Mkdir.new(operand["mode"], operand["user"], operand["group"], operand["source"])
      when "MV"
        Protocol::Command::Mv.new(operand["mode"], operand["user"], operand["group"], 
                                  operand["source"], operand["dest"])
      else
        raise "Protocol parse error - unsupported opecode."
      end
    end

    def error_response error = {}
      Protocol::Response.new(error)
    end
  end

  ##
  # NOP Command instance.
  #
  class Protocol::Command::Nop < Protocol::Command
    def to_s
      [ "1.1", "C", "NOP", {}].to_json + "\r\n"
    end
  end

  ##
  # CREATE Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Create.new({
  #   "basket" => b,
  #   "hints" => {
  #     "class" => "original",
  #     "length" => 12345
  #   }
  # })
  #
  # puts cmd.basket
  # => 123.1.5
  # puts cmd.hints.klass
  # => "original"
  # puts cmd.hints.length
  # => 12345
  # </pre>
  #
  class Protocol::Command::Create < Protocol::Command
    attr_reader :basket, :hints
    def initialize basket, hints
      @basket = basket.to_basket
      raise "hints should be a Hash."  unless hints.kind_of? Hash
      raise "Nil cannot be set for class."  unless hints["class"]

      @hints = hints.dup
      @hints["class"]  = @hints["class"].to_s
      @hints["length"] = @hints["length"].to_i

      class << @hints
        def klass ; self["class"]; end
        def length; self["length"]; end
      end
    end
    def to_s
      [ "1.1", "C", "CREATE", {"basket" => (@basket ? @basket.to_s : @basket), "hints" => @hints }].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Create::Gateway.new(error, @basket, [])
    end
  end

  ##
  # FINALIZE Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Finalize.new b
  #
  # puts cmd.basket
  # => 123.1.5
  # </pre>
  #
  class Protocol::Command::Finalize < Protocol::Command
    attr_reader :basket, :host, :path
    def initialize basket, host, path
      @basket = basket.to_basket
      raise "Nil cannot be set for host." unless host
      raise "Nil cannot be set for path." unless path
      @host, @path = host.to_s, path.to_s
    end
    def to_s
      [ "1.1", "C", "FINALIZE", {"basket" => (@basket ? @basket.to_s : @basket), "host" => @host, "path" => @path}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Finalize.new(error, @basket)
    end
  end

  ##
  # CANCEL Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Cancel.new b
  #
  # puts cmd.basket
  # => 123.1.5
  # </pre>
  #
  class Protocol::Command::Cancel < Protocol::Command
    attr_reader :basket, :host, :path
    def initialize basket, host, path
      @basket = basket.to_basket
      raise "Nil cannot be set for host." unless host
      raise "Nil cannot be set for path." unless path
      @host, @path = host.to_s, path.to_s
    end
    def to_s
      [ "1.1", "C", "CANCEL", {"basket" => (@basket ? @basket.to_s : @basket), "host" => @host, "path" => @path}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Cancel.new(error, @basket)
    end
  end

  ##
  # GET Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Get.new b
  #
  # puts cmd.basket
  # => 123.1.5
  # </pre>
  #
  class Protocol::Command::Get < Protocol::Command
    attr_reader :basket, :island
    def initialize basket, island = nil
      @basket = basket.to_basket
      @island = island
    end
    def to_s
      operand = {}
      operand["basket"] = (@basket ? @basket.to_s : @basket)
      operand["island"] = @island.to_s if @island
      [ "1.1", "C", "GET", operand].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Get.new(error, @basket, {})
    end
  end

  ##
  # DELETE Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Delete.new b
  #
  # puts cmd.basket
  # => 123.1.5
  # </pre>
  #
  class Protocol::Command::Delete < Protocol::Command
    attr_reader :basket
    def initialize basket
      @basket = basket.to_basket
    end
    def to_s
      [ "1.1", "C", "DELETE", {"basket" => (@basket ? @basket.to_s : @basket)}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Delete.new(error, @basket)
    end
  end

  ##
  # INSERT Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Insert.new({
  #   "basket" => b,
  #   "info" => { "class" => "original" },
  #   "paths => {
  #     "std100" => "/expdsk/0/a/0/987/654/987654321.1.2",
  #     "std101" => "/expdsk/0/a/0/987/654/987654321.1.2",
  #   }
  # })
  #
  # puts cmd.basket
  # => 123.1.5
  # puts cmd.info.klass
  # => "original"
  # puts cmd.paths["
  # => 12345
  # </pre>
  #
  class Protocol::Command::Insert < Protocol::Command
    attr_reader :basket, :host, :path
    def initialize basket, host, path
      @basket = basket.to_basket
      raise "Nil cannot be set for host." unless host
      raise "Nil cannot be set for path." unless path
      @host, @path = host.to_s, path.to_s
    end
    def to_s
      [ "1.1", "C", "INSERT", {"basket" => (@basket ? @basket.to_s : @basket), "host" => @host, "path" => @path}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Insert.new(error)
    end
  end

  ##
  # DROP Command instance.
  #
  # <pre>
  # b = Castoro::BasketKey.new(123, 1, 5)
  # cmd = Protocol::Command::Drop.new "basket" => b
  #
  # puts cmd.basket
  # => 123.1.5
  # </pre>
  #
  class Protocol::Command::Drop < Protocol::Command
    attr_reader :basket, :host, :path
    def initialize basket, host, path
      @basket = basket.to_basket
      raise "Nil cannot be set for host." unless host
      raise "Nil cannot be set for path." unless path
      @host, @path = host.to_s, path.to_s
    end
    def to_s
      [ "1.1", "C", "DROP", {"basket" => (@basket ? @basket.to_s : @basket), "host" => @host, "path" => @path}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Drop.new(error)
    end
  end

  class Protocol::Command::Alive < Protocol::Command
    attr_reader :host, :status, :available
    def initialize host, status, available
      raise "Nil cannot be set for host." unless host
      raise "Nil cannot be set for status." unless status
      raise "Nil cannot be set for available." unless available
      @host, @status, @available = host.to_s, status.to_i, available.to_i
    end
    def to_s
      [ "1.1", "C", "ALIVE", {"host" => @host, "status" => @status, "available" => @available}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Alive.new(error)
    end
  end

  class Protocol::Command::Island < Protocol::Command
    attr_reader :island, :storables, :capacity
    def initialize island, storables, capacity
      raise "Nil cannot be set for island." unless island 
      raise "Nil cannot be set for storables." unless storables
      raise "Nil cannot be set for capacity." unless capacity
      @island, @storables, @capacity = island.to_s, storables.to_i, capacity.to_i
    end
    def to_s
      operand = {}
      operand["island"] = @island
      operand["storables"] = @storables
      operand["capacity"] = @capacity
      [ "1.1", "C", "ISLAND", operand].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Island.new(error)
    end
  end

  class Protocol::Command::Status < Protocol::Command
    def to_s
      [ "1.1", "C", "STATUS", {}].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Status.new(error)
    end
  end

  class Protocol::Command::Dump < Protocol::Command
    def to_s
      [ "1.1", "C", "DUMP", {}].to_json + "\r\n"
    end
  end

  class Protocol::Command::Mkdir < Protocol::Command
    attr_reader :mode, :user, :group, :source
    def initialize mode, user, group, source
      raise "Nil cannot be set for mode."   unless mode
      raise "Nil cannot be set for user."   unless user
      raise "Nil cannot be set for group."  unless group
      raise "Nil cannot be set for source." unless source
      if mode.kind_of? Numeric
        @mode = mode
      else
        raise "mode should set the Numeric or octal number character." unless mode.to_s =~ /^[01234567]+$/
        @mode = mode.oct
      end
      @user, @group, @source = user, group, source
    end
    def to_s
      operand = {
        "mode" => @mode.to_s(8),
        "user" => @user,
        "group" => @group,
        "source" => @source,
      }
      [ "1.1", "C", "MKDIR", operand ].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Mkdir.new(error)
    end
  end

  class Protocol::Command::Mv < Protocol::Command
    attr_reader :mode, :user, :group, :source, :dest
    def initialize mode, user, group, source, dest
      raise "Nil cannot be set for mode."   unless mode
      raise "Nil cannot be set for user."   unless user
      raise "Nil cannot be set for group."  unless group
      raise "Nil cannot be set for source." unless source
      raise "Nil cannot be set for dest."   unless dest
      if mode.kind_of? Numeric
        @mode = mode
      else
        raise "mode should set the Numeric or octal number character." unless mode.to_s =~ /^[01234567]+$/
        @mode = mode.oct
      end
      @user, @group, @source, @dest = user, group, source, dest
    end
    def to_s
      operand = {
        "mode" => @mode.to_s(8),
        "user" => @user,
        "group" => @group,
        "source" => @source,
        "dest" => @dest,
      }
      [ "1.1", "C", "MV", operand ].to_json + "\r\n"
    end
    def error_response error = {}
      Protocol::Response::Mv.new(error)
    end
  end

  class Protocol::Response < Protocol
    attr_reader :error
    def self.parse opecode, operand
      case opecode
      when "NOP"
        Protocol::Response::Nop.new(operand["error"])
      when "CREATE"
        if operand.include?("hosts")
          Protocol::Response::Create::Gateway.new(operand["error"], operand["basket"], operand["hosts"], operand["island"])
        elsif operand.include?("host") and operand.include?("path")
          Protocol::Response::Create::Peer.new(operand["error"], operand["basket"], operand["host"], operand["path"])
        else
          Protocol::Response::Create.new(operand["error"], operand["basket"])
        end
      when "FINALIZE"
        Protocol::Response::Finalize.new(operand["error"], operand["basket"])
      when "CANCEL"
        Protocol::Response::Cancel.new(operand["error"], operand["basket"])
      when "GET"
        Protocol::Response::Get.new(operand["error"], operand["basket"], operand["paths"], operand["island"])
      when "DELETE"
        Protocol::Response::Delete.new(operand["error"], operand["basket"])
      when "INSERT"
        Protocol::Response::Insert.new(operand["error"])
      when "DROP"
        Protocol::Response::Drop.new(operand["error"])
      when "ALIVE"
        Protocol::Response::Alive.new(operand["error"])
      when "ISLAND"
        Protocol::Response::Island.new(operand["error"])
      when "STATUS"
        Protocol::Response::Status.new(operand["error"], operand["status"])
      when "MKDIR"
        Protocol::Response::Mkdir.new(operand["error"])
      when "MV"
        Protocol::Response::Mv.new(operand["error"])
      when nil
        Protocol::Response.new(operand["error"])
      else
        raise "Protocol parse error - unsupported opecode."
      end
    end

    def initialize error
      @error = error
    end
    def error?; !!@error; end
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", nil, operand].to_json + "\r\n"
    end

  end

  class Protocol::Response::Nop < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "NOP", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Create < Protocol::Response
    attr_reader :basket
    def initialize error, basket
      super error
      unless @error
        @basket = basket.to_basket
      end
    end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket)}
      operand["error"] = @error if @error
      [ "1.1", "R", "CREATE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Create::Gateway < Protocol::Response::Create
    include Enumerable

    attr_reader :hosts, :island
    def initialize error, basket, hosts, island = nil
      super error, basket
      unless @error
        raise "Nil cannot be set for hosts." unless hosts
        @hosts = hosts.to_a
        @island = island
      end
    end
    def each(&block); @hosts.each(&block); end
    def [](index); @hosts[index]; end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket), "hosts" => @hosts}
      operand["island"] = @island.to_s if @island
      operand["error"] = @error if @error
      [ "1.1", "R", "CREATE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Create::Peer < Protocol::Response::Create
    attr_reader :host, :path
    def initialize error, basket, host, path
      super error, basket
      unless @error
        raise "Nil cannot be set for host." unless host
        raise "Nil cannot be set for path." unless path
        @host, @path = host.to_s, path.to_s
      end
    end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket), "host" => @host, "path" => @path}
      operand["error"] = @error if @error
      [ "1.1", "R", "CREATE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Finalize < Protocol::Response
    attr_reader :basket
    def initialize error, basket
      super error
      unless @error
        @basket = basket.to_basket
      end
    end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket)}
      operand["error"] = @error if @error
      [ "1.1", "R", "FINALIZE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Cancel < Protocol::Response
    attr_reader :basket
    def initialize error, basket
      super error
      unless @error
        @basket = basket.to_basket
      end
    end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket)}
      operand["error"] = @error if @error
      [ "1.1", "R", "CANCEL", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Get < Protocol::Response
    include Enumerable

    attr_reader :basket, :paths, :island
    def initialize error, basket, paths, island = nil
      super error
      @paths = {}
      unless @error
        @basket = basket.to_basket
        @island = island

        raise "paths should be a Hash." unless paths.kind_of? Hash
        @paths = paths.dup
      end
    end
    def each(&block); @paths.each(&block); end
    def each_key(&block); @paths.each_key(&block); end
    def [](index); @paths[index]; end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket), "paths" => @paths}
      operand["island"] = @island.to_s if @island
      operand["error"] = @error if @error
      [ "1.1", "R", "GET", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Delete < Protocol::Response
    attr_reader :basket
    def initialize error, basket
      super error
      unless @error
        @basket = basket.to_basket
      end
    end
    def to_s
      operand = {"basket" => (@basket ? @basket.to_s : @basket)}
      operand["error"] = @error if @error
      [ "1.1", "R", "DELETE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Insert < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "INSERT", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Drop < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "DROP", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Alive < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "ALIVE", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Island < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "ISLAND", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Status < Protocol::Response
    include Enumerable
    attr_reader :status

    def initialize error, status = {}
      super error
      status ||= {}
      unless @error
        raise "status should be a Hash." unless status.kind_of? Hash
        @status = status.dup
      end
    end
    def to_s
      operand = {"status" => (@status || {})}
      operand["error"] = @error if @error
      [ "1.1", "R", "STATUS", operand].to_json + "\r\n"
    end
    def method_missing method_name, *arguments, &block
      @status.send method_name, *arguments, &block
    end
  end

  class Protocol::Response::Mkdir < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "MKDIR", operand].to_json + "\r\n"
    end
  end

  class Protocol::Response::Mv < Protocol::Response
    def to_s
      operand = {}
      operand["error"] = @error if @error
      [ "1.1", "R", "MV", operand].to_json + "\r\n"
    end
  end

  class Protocol::UDPHeader
    def self.parse values
      begin
        values = JSON.parse(values) if values.kind_of? String
      rescue JSON::ParserError
        raise "Protocol parse error - Illegal JSON format."
      end
      raise ProtocolError, "Protocol parse error." unless values.kind_of? Array
      raise ProtocolError, "Protocol parse error." unless values.length == 3

      ip, port, sid = values
      Protocol::UDPHeader.new(ip, port, sid)

    rescue RuntimeError => e
      raise ProtocolError, e.message
    end

    attr_reader :ip, :port, :sid
    def initialize ip, port, sid = 0
      raise ProtocolError, "port should be a Fixnum." unless port.kind_of? Fixnum
      raise ProtocolError, "sid should be a Numeric." unless sid.kind_of? Numeric

      @ip, @port, @sid = ip.to_s, port, sid
    end
    def to_s; [@ip, @port, @sid].to_json + "\r\n"; end
  end

end
