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
require "monitor"

##
# Castoro::Client
#
# It is a class to connect with Castoro::Gateway and to acquire the result.
#
module Castoro
  class ClientError < CastoroError; end
  class ClientTimeoutError < ClientError; end
  class ClientNoRetryError < ClientError; end
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
    # #new, #open and #close are executed.
    #
    # === Args
    #
    # see #initialize
    #
    # === Example
    #
    #  Castoro::Client.open(conf) { |cli|
    #    # "cli" is opened client instance.
    #    cli.get ...
    #  }
    #  # "cli" is closed after block is evaluated.
    #
    def self.open options
      raise ClientError, "It is necessary to specify the block argument." unless block_given?
      Client.new(options) { |cli|
        cli.open
        begin
          yield cli if block_given?
        ensure
          cli.close
        end
      }
    end

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

      @locker = Monitor.new

      yield self if block_given?
    end

    ##
    # open client.
    #
    def open
      @locker.synchronize {
        raise ClientError, "client already opened." if opened?

        @logger.info { "*** castoro-client open." }
        @sender.start
      }
    end

    ##
    # close client.
    #
    def close
      @locker.synchronize {
        raise ClientError, "client already closed." if closed?

        @sender.stop
        @logger.info { "*** castoro-client close." }
      }
    end

    def opened?; @locker.synchronize { @sender.alive? } ; end
    def closed?; @locker.synchronize { !opened?       } ; end

    def sid
      @sender ? @sender.sid : nil
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
    #  k = Castoro::BasketKey.new(123456, :original, 1)
    #  res = client.get k
    #  res
    #  => {"peer1" => "/foo/bar/baz", "peer2" => "/hoge/fuga"}
    #
    def get key
      @locker.synchronize {
        raise ClientError, "Client is not opened." unless opened?

        @logger.info { "[key:#{key}] send GET request to gateways" }
        res = @sender.send Protocol::Command::Get.new(key)
        raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Get
        raise ClientError, "get command failed - #{res.inspect}." if res.error?
        res.paths.to_hash
      }
    end

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
    #  k = Castoro::BasketKey.new(123456, :original, 1)
    #  client.create(k, "length" => 99999, "class" => :original) { |host, path|
    #    # It accessed the mountpoint by using the value of host and path...
    #
    #    # When the block ends normally, finalize is issued.
    #    # When the block terminates abnormally, cancel is issued.
    #  }
    #
    # === Flow & Errors
    #
    # <b>CREATE command try following flow to peers.</b>
    #
    # * but if no peers can be connected, client raise
    #   - Castoro::ClientNothingPeerError "[key:#{key}] There is no Peer that can be connected by TCP."
    #
    # ==== Processing flow
    #
    # 1. Client connect to the specified peer and send CREATE command.
    #
    # 2. Then, if some kind of error raised, 
    #    client retry to connect and send CREATE command to the next peer.
    #
    #    * but if no peers remined which can be used, raise the error and finish this process.
    #    * In case of the error is caused by the basket already existing in peer, 
    #      client raise the error and finish this process without retry.
    #
    #    <b>Possible Errors</b>
    #
    #    * When no response is returned to client for a given length of time, client raise
    #      - ClientTimeoutError, "create command timeout - #{peer}"
    #
    #    * When the response of CREATE command is not intended one, client raise
    #      - ClientError, "Response not intended. - #{res.class}"
    #
    #    * When the peer returned "Castoro::Peer::AlreadyExistsError", client raise
    #      - ClientAlreadyExistsError, "[key:#{cmd.basket}] Basket already exists in peers - #{res.error["message"]}"
    #
    #    * When peer raise some other errors, client raise
    #      - ClientError, "create command failed - #{res.inspect}, #{peer}."
    #
    # 3. When CREATE command is accepted correctly, client try to yield (application code).
    #
    # 4. Then, if some kind of error raised while yielding, 
    #    client send CANCEL command to the peer and retry to the next peer.
    #
    #    * but if no peers remined which can be used, raise the error and finish this process.
    #    * In case of the error is for canceling this process,
    #      client raise the error to the application and finish this process without retry.
    #
    #    <b>Possible Errors</b>
    #
    #    * When the error which the application raise is for canceling (Castoro::ClientNoRetryError), 
    #      client raise the error.
    #
    #    * When the application raise some other errors, client raise the error.
    # 
    # 5. When succeeded in yielding, client send FINALIZE command to peer.
    #
    # 6. Then, if some kind of error raised, client send CANCEL command to the peer 
    #    and raise the error and finish this process without retry.
    #
    #    <b>Possible Errors</b>
    #
    #    * When no response is returned to client for a given length of time, client raise
    #      - ClientTimeoutError, "finalize command timeout - #{peer}"
    #
    #    * When the response of FINALIZE command is not intended one, client raise
    #      - ClientError, "Response not intended. - #{res.class}"
    #
    #    * When peer raise some other errors, client raise
    #      - ClientError, "finalize command failed - #{res.inspect}, #{peer}."
    #
    # ==== Error handling example in the client application
    #
    #  begin
    #    Castoro::Client.open(conf) { |cli|
    #      cli.create...
    #    }
    #  rescue => e
    #    # e.class   == "Castoro::ClientTimeoutError"
    #    # e.message == "create command timeout - host123"
    #  end
    #
    def create key, hints = {}, &block
      @locker.synchronize {
        raise ClientError, "Client is not opened." unless opened?
        raise ClientError, "It is necessary to specify the block argument." unless block

        key = key.to_basket
        hints ||= {}

        # craete command.
        cmd = Protocol::Command::Create.new key, hints

        # get available peers from gateway.
        @logger.info { "[key:#{key}] send CREATE request to gateways" }
        res = @sender.send cmd
        raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Create::Gateway
        raise ClientError, "gateway connection failed - #{res.inspect}" if res.error?

        peers = res.hosts
        connected = connect(peers) { |connection, peer, remining_peers| 
          create_internal(connection, peer, remining_peers, cmd, &block) 
        }

        raise ClientNothingPeerError, "[key:#{key}] There is no Peer that can be connected by TCP." unless connected
      }
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
    #  peer = "std100"
    #  k = Castoro::BasketKey.new(123456, :original, 1)
    #  
    #  client.create_direct(peer, k, "length" => 99999, "class" => :original) { |host, path|
    #    # It accessed the mountpoint by using the value of host and path...
    # 
    #    # When the block ends normally, finalize is issued.
    #    # When the block terminates abnormally, cancel is issued.
    #  }
    #
    def create_direct peer, key, hints = {}, &block
      @locker.synchronize {
        raise ClientError, "Client is not opened." unless opened?
        raise ClientError, "It is necessary to specify the block argument." unless block

        key = key.to_basket
        hints ||= {}

        # craete command.
        cmd = Protocol::Command::Create.new key, hints

        peers = [peer].flatten
        connected = connect(peers) { |connection, peer, remining_peers| 
          create_internal(connection, peer, remining_peers, cmd, &block) 
        }

        raise ClientNothingPeerError, "[key:#{key}] There is no Peer that can be connected by TCP." unless connected
      }
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
    #  k = Castoro::BasketKey.new(123456, :original, 1)
    #  client.delete k
    #
    def delete key
      @locker.synchronize {
        raise ClientError, "Client is not opened." unless opened?

        key = key.to_basket

        peers = get(key).keys.dup

        # shuffle.
        (sid % peers.length).times { peers.push(peers.shift) }

        cmd = Protocol::Command::Delete.new key

        connected = connect(peers) { |connection, peer, remining_peers| 
          delete_internal(connection, peer, remining_peers, cmd)
        }
        
        raise ClientNothingPeerError, "[key:#{key}] There is no Peer that can be connected by TCP." unless connected
        
        nil
      }
    end

    private

    def create_internal connection, peer, remining_peers, cmd, &block

      # CREATE
      @logger.info { "[key:#{cmd.basket}] send CREATE request to peer<#{peer}>" }
      res = connection.send cmd, @tcp_request_expire
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

      # choice tcp connection from available one peer(s).
      begin
        # yield
        yield host, path

        begin
          # FINALIZE
          @logger.info { "[key:#{cmd.basket}] send FINALIZE request to peer<#{peer}>" }
          res = connection.send Protocol::Command::Finalize.new(cmd.basket, host, path), @tcp_request_expire
          raise ClientTimeoutError, "finalize command timeout - #{peer}" if res.nil?
          raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Finalize
          raise ClientError, "finalize command failed - #{res.inspect}, #{peer}." if res.error?

          @logger.debug { "Finalize ended." }

        rescue => e
          # finalize error log.
          @logger.error { e.message }
          @logger.debug { e.backtrace.join("\n\t") }

          # Retrying is controlled by clearing remining_peers.
          remining_peers.clear
          raise
        end

      rescue => e
        begin
          # CANCEL
          @logger.info { "[key:#{cmd.basket}] send CANCEL request to peer<#{peer}>" }
          res = connection.send Protocol::Command::Cancel.new(cmd.basket, host, path), @tcp_request_expire
          @logger.info { "cancel command timeout - #{peer}" } if res.nil?
          @logger.info { "Response not intended. - #{res.class}" } unless res.kind_of? Protocol::Response::Cancel
          @logger.info { "cancel command failed - #{res.inspect}, #{peer}." } if res.error?
        rescue => cancel_error
          @logger.error { cancel_error.message }
          @logger.debug { cancel_error.backtrace.join("\n\t") }
        end

        remining_peers.clear if e.class == ClientNoRetryError
        raise
      end

    rescue => e
      connection.stop

      raise if e.class == ClientAlreadyExistsError
      raise if remining_peers.empty?
      raise unless connect(remining_peers) { |c, p, ps| create_internal(c, p, ps, cmd, &block) }
    end

    def delete_internal connection, peer, remining_peers, cmd
      @logger.info { "[key:#{cmd.basket}] send DELETE request to peer<#{peer}>" }
      res = connection.send cmd, @tcp_request_expire
        
      raise ClientTimeoutError, "delete command timeout - #{peer}" if res.nil?
      raise ClientError, "Response not intended. - #{res.class}" unless res.kind_of? Protocol::Response::Delete
      raise ClientError, "delete command failed - #{res.inspect}, #{peer}." if res.error?
      
    rescue => e
      connection.stop

      raise if remining_peers.empty?
      raise unless connect(remining_peers) { |c, p, ps| delete_internal(c, p, ps, cmd) }
    end

    ##
    # Peer is selected and it connects it.
    #
    # === Args
    #
    # +peers+::
    #   Selection candidate of Peer.
    #
    def connect peers
      until peers.empty?
        peer = peers.shift

        connection = begin
                       # connect.
                       s = Sender::TCP.new @logger, peer, @peer_port
                       s.start @tcp_connect_expire
                       s
                     rescue; nil
                     end
        
        if connection
          begin
            yield connection, peer, peers
          ensure
            connection.stop if connection.alive?
          end

          return true
        end
      end

      false
    end

  end
end
