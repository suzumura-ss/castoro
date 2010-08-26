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

require "logger"
require "socket"
require "yaml"
require "timeout"
require "thread"

##
# Castoro::Client
#
# It is a class to connect with Castoro::Gateway and to acquire the result.
#
module Castoro
  class ClientError < CastoroError; end
  class ClientTimeoutError < ClientError; end
  class ClientNothingPeerError < ClientError; end
  class ClientAlreadyExistsError < ClientError; end

  class Client

    GATEWAY_DEFAULT_PORT = 30111
    PEER_DEFAULT_PORT = 30111

    DEFAULT_SETTINGS = {
      "my_host" => IPSocket::getaddress(Socket::gethostname),
      "my_ports" => (30003..30099),
      "expire" => 2.0,
      "request_interval" => 0.20,
      "gateways" => [ "127.0.0.1" ],
      "peer_port" => PEER_DEFAULT_PORT,
      "tcp_connect_expire" => 0.05,
      "tcp_connect_retry" => 1,
      "tcp_request_expire" => 5.00,
      "logger" => nil, # Logger.new(STDOUT)
    }

    ##
    # Initialize
    #
    # === Args
    #
    # +options+::
    #   client options.
    #
    # Valid options for +options+ are:
    #
    # "logger"::
    #     The logger.
    # "my_host"::
    #     Host name that can be recognized from other hosts.
    # "my_ports"::
    #     Range of UDP port number that can be secured.
    # "expire"::
    #     UDP response timeout (second).
    # "request_interval"::
    #     Interval when packet is transmitted to the next host.
    # "gateways"::
    #     Array of character string that shows destination address (and port)
    # "peer_port"::
    #     Port number used when it access peer.
    # "tcp_connect_expire"::
    #     TCP connect timeout (second).
    # "tcp_connect_retry"::
    #     Connected trial frequency to peer.
    # "tcp_request_expire"::
    #     TCP request timeout (second).
    #
    def initialize options = {}

      opt = DEFAULT_SETTINGS.merge(options)

      @logger = opt["logger"] || Logger.new(STDOUT)

      # The fllowing kinds can be accepted.
      # - Hash(deprecated)
      #     { "host" => "foo", "port" => 30111 }
      # - String
      #     "foo:30111"
      gateways = opt["gateways"].map! { |g|
        if g.kind_of?(Hash)
          "#{g["host"]}:#{(g["port"] || GATEWAY_DEFAULT_PORT)}"
        else
          elems = g.split(":")
          "#{elems[0]}:#{(elems[1] || GATEWAY_DEFAULT_PORT)}"
        end
      }

      @sender = TimeslideSender.new(@logger, opt["my_host"],
                                             opt["my_ports"].to_a,
                                             gateways,
                                             opt["expire"],
                                             opt["request_interval"])


      @logger.info { "my_host => #{opt["my_host"]}" }
      @logger.info { "gateways\n#{gateways.to_yaml}" }

      @peer_port          = opt["peer_port"]
      @tcp_connect_expire = opt["tcp_connect_expire"]
      @tcp_connect_retry  = opt["tcp_connect_retry"]
      @tcp_request_expire = opt["tcp_request_expire"]

      @mutex = Mutex.new
      @nop   = Protocol::Command::Nop.new
    end

    ##
    # open client.
    #
    def open
      @mutex.synchronize {
        raise ClientError, "client already opened." if opened?

        @logger.info { "*** castoro-client open." }
        @sender.start
      }
    end

    ##
    # close client.
    #
    def close
      @mutex.synchronize {
        raise ClientError, "client already closed." if closed?

        @sender.stop
        @logger.info { "*** castoro-client close." }
      }
    end

    def opened?; @sender.alive?; end
    def closed?; !opened?; end

    ##
    # A safe contents addition procedure is offered.
    #
    # === Args
    #
    # +key+::
    #   The basket key.
    # +hints+::
    #   hints for create content.
    #
    # === Example
    #
    # <pre>
    # k = Castoro::BasketKey.new(123456, :original, 1)
    # client.create(k, "length" => 99999, "class" => :original) { |host, path|
    #   # It accessed the mountpoint by using the value of host and path...
    #
    #   # When the block ends normally, finalize is issued.
    #   # When the block terminates abnormally, cancel is issued.
    # }
    # </pre>
    #
    def create key, hints = {}, &block
      raise ClientError, "Client is not opened." unless opened?
      raise ClientError, "It is necessary to specify the block argument." unless block

      key = key.to_basket
      hints ||= {}

      # craete command.
      cmd = Protocol::Command::Create.new key, hints

      # get available peers from gateway.
      @logger.info { "[key:#{key}] send CREATE request to gateways" }
      res = send(cmd)
      raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Create::Gateway
      raise ClientError, "gateway connection failed - #{res.inspect}" if res.error?

      create_internal res.hosts, cmd, &block
    end

    ##
    # CREATE command is issued to specific Peer.
    #
    # +peer+::
    #   Peer hostname(s).
    # +key+::
    #   The basket key.
    # +hints+::
    #   hints for create content.
    #
    # === Example
    #
    # <pre>
    # peer = "std100"
    # k = Castoro::BasketKey.new(123456, :original, 1)
    # 
    # client.create_direct(peer, k, "length" => 99999, "class" => :original) { |host, path|
    #   # It accessed the mountpoint by using the value of host and path...
    #
    #   # When the block ends normally, finalize is issued.
    #   # When the block terminates abnormally, cancel is issued.
    # }
    # </pre>
    #
    def create_direct peer, key, hints = {}, &block
      raise ClientError, "Client is not opened." unless opened?
      raise ClientError, "It is necessary to specify the block argument." unless block

      key = key.to_basket
      hints ||= {}

      # craete command.
      cmd = Protocol::Command::Create.new key, hints

      create_internal [peer].flatten, cmd, &block
    end

    ##
    # Delete basket.
    #
    # === Args
    #
    # +key+::
    #   The basket key.
    #
    # === Example
    #
    # <pre>
    # k = Castoro::BasketKey.new(123456, :original, 1)
    # client.delete k
    # </pre>
    #
    def delete key
      raise ClientError, "Client is not opened." unless opened?

      key = key.to_basket

      peers = get(key).keys.dup

      # shuffle.
      (sid % peers.length).times { peers.push(peers.shift) }

      peer_decide_proc = Proc.new { |sender, peer|
        # DELETE
        cmd = Protocol::Command::Delete.new key
        @logger.info { "[key:#{cmd.basket}] send DELETE request to peer<#{peer}>" }
        res = sender.send cmd, @tcp_request_expire
        raise ClientTimeoutError, "delete command timeout - #{peer}" if res.nil?
        raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Delete
        raise ClientError, "delete command failed - #{res.inspect}, #{peer}." if res.error?
      }

      # choice tcp connection from available one peer(s).
      open_peer_connection(key, peers, peer_decide_proc)
      nil
    end

    ##
    # Get basket.
    #
    # === Args
    #
    # +key+::
    #   The basket key.
    #
    # === Example
    #
    # <pre>
    # k = Castoro::BasketKey.new(123456, :original, 1)
    # res = client.get k
    # res
    # => {"peer1" => "/foo/bar/baz", "peer2" => "/hoge/fuga"}
    # </pre>
    def get key
      raise ClientError, "Client is not opened." unless opened?

      @logger.info { "[key:#{key}] send GET request to gateways" }
      res = send Protocol::Command::Get.new(key)
      raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Get
      raise ClientError, "get command failed - #{res.inspect}." if res.error?
      res.paths.to_hash
    end

    def sid
      @sender ? @sender.sid : nil
    end

  private

    def send command
      @mutex.synchronize {
        @sender.send command
      }
    end

    def create_internal peers, cmd

      host, path = nil, nil

      peer_decide_proc = Proc.new { |sender, peer|
        # CREATE
        @logger.info { "[key:#{cmd.basket}] send CREATE request to peer<#{peer}>" }
        res = sender.send cmd, @tcp_request_expire
        raise ClientTimeoutError, "create command timeout - #{peer}" if res.nil?
        raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Create

        if res.error?
          if res.error["code"] == "Castoro::Peer::AlreadyExistsError"
            raise ClientAlreadyExistsError, "[key:#{cmd.basket}] Basket already exists in peers - #{res.error["message"]}"
          else
            raise ClientError, "create command failed - #{res.inspect}, #{peer}."
          end
        end

        host, path = res.host, res.path
      }

      # choice tcp connection from available one peer(s).
      open_peer_connection(cmd.basket, peers, peer_decide_proc) { |sender, peer|
        begin
          yield host, path

          # FINALIZE
          @logger.info { "[key:#{cmd.basket}] send FINALIZE request to peer<#{peer}>" }
          res = sender.send Protocol::Command::Finalize.new(cmd.basket, host, path), @tcp_request_expire
          raise ClientTimeoutError, "finalize command timeout - #{peer}" if res.nil?
          raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Finalize
          raise ClientError, "finalize command failed - #{res.inspect}, #{peer}." if res.error?

          @logger.debug { "Finalize ended." }

        rescue => e
          # finalize error log.
          @logger.error { e.message }
          @logger.debug { e.backtrace.join("\n\t") }

          begin
            # CANCEL
            @logger.info { "[key:#{cmd.basket}] send CANCEL request to peer<#{peer}>" }
            res = sender.send Protocol::Command::Cancel.new(cmd.basket, host, path), @tcp_request_expire
            @logger.info { "cancel command timeout - #{peer}" } if res.nil?
            @logger.info { "Response not intended. - #{res.class}" } unless res.kind_of? Protocol::Response::Cancel
            @logger.info { "cancel command failed - #{res.inspect}, #{peer}." } if res.error?
          rescue => e
            @logger.error { e.message }
            @logger.debug { e.backtrace.join("\n\t") }
          end

          raise
        end

        res
      }
    end

    ##
    # Peer is selected and it connects it.
    #
    # === Args
    #
    # +basket+::
    #   The basket key.
    # +peers+::
    #   Selection candidate of Peer.
    # +peer_decide_proc+::
    #   Selection condition of Peer.
    #
    def open_peer_connection basket, peers, peer_decide_proc = nil
      sender, peer = nil, nil
      ( peers * (1 + @tcp_connect_retry.to_i) ).each { |p|
        s = nil
        begin
          s = Sender::TCP.new @logger, p, @peer_port
          s.start @tcp_connect_expire
          res = s.send(@nop, @tcp_connect_expire)
          raise ClientTimeoutError, "nop command timeout - #{p}" if res.nil?
          raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Nop
          raise ClientError, "nop command failed - #{res.inspect}, #{p}." if res.error?

          peer_decide_proc.call(s, p) if peer_decide_proc

          sender, peer = s, p
          break

        rescue => e
          if s and s.alive?
            s.stop rescue nil
          end
          raise if e.class == ClientAlreadyExistsError
        end
      }
      raise ClientNothingPeerError, "[key:#{basket}] There is no Peer that can be connected by TCP." unless sender

      begin
        if block_given?
          @logger.info { "[key:#{basket}] peer connection was decided <#{peer}>" }
          yield sender, peer
        end
      ensure
        sender.stop
      end
    end

  end
end
