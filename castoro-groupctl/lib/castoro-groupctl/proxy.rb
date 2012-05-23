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

require 'thread'
require 'singleton'
require 'castoro-groupctl/barrier'
require 'castoro-groupctl/command'
require 'castoro-groupctl/server_status'

module Castoro
  module Peer

    class XBarrier < MasterSlaveBarrier
      include Singleton
    end

    class Proxy
      attr_reader :ps

      def initialize hostname, target
        @hostname, @target  = hostname, target
      end

      def execute command, &block
        Thread.new do
          begin
            XBarrier.instance.wait
            yield command
          rescue => e
#            command.exception = e
            command.error = "#{e.class} #{e.message}"  # "#{e.backtrace.join(' ')}"
          ensure
            XBarrier.instance.wait
          end
        end
      end

      def do_ps
        @ps = Command::Ps.new @hostname, @target
        execute( @ps ) { |c| c.execute }
      end

      def do_status
        @status = Command::Status.new @hostname, @target
        execute( @status ) { |c| c.execute }
      end

      def do_start
        @start = Command::Start.new @hostname, @target
        execute( @start ) { |c| c.execute }
      end

      def do_stop
        @stop = Command::Stop.new @hostname, @target
        execute( @stop ) { |c| c.execute }
      end

#      def shutdown
#        @shutdown = Command::Stop.new @hostname, @target
#        execute( @shutdown ) { |c| c.execute }
#      end

      def do_mode mode
        @mode = Command::Mode.new @hostname, @target
        execute( @mode ) { |c| c.execute mode }
      end

      def ascend_mode mode
        @mode = Command::Mode.new @hostname, @target
        if @status_mode.nil? or @status_mode < mode
          do_mode mode
        else
          execute( @mode ) do |c|
            c.message = "Do nothing since the mode is already #{ServerStatus.status_code_to_s( @status_mode )}"
          end
        end
      end

      def descend_mode mode
        if @status_mode.nil? or mode < @status_mode
          do_mode mode
        else
          Thread.new do
            begin
              XBarrier.instance.wait
              @mode_error = nil
              @mode_message = "Do nothing since the mode is already #{ServerStatus.status_code_to_s( @status_mode )}"
              XBarrier.instance.wait
            end
          end
        end
      end

      attr_reader :auto_error, :auto_message

      def do_auto auto
        @auto_error = nil
        @auto_message = nil
        execute_to_cagentd( 'AUTO', { :target => @target, :auto => auto } ) do |h, t, r|  # hostname, target, response
          if r.nil?
            #
          elsif r.has_key? 'error'
            e = r[ 'error' ]
            @auto_error = "#{e['code']}: #{e['message']}"
          elsif r.has_key? 'auto'
            @status_auto = r[ 'auto' ]
            f = r[ 'auto_previous' ].nil? ? 'unknown' : ( r[ 'auto_previous' ] ? 'auto' : 'off' )
            t = r[ 'auto' ].nil? ? 'unknown' : ( r[ 'auto' ] ? 'auto' : 'off' )
            @auto_message = "Autopilot has changed from #{f} to #{t}"
          else
            @auto_error = "Unknown error: #{r.inspect}"
          end
        end
      end
    end


    class ManipulatordProxy < Proxy
      def initialize hostname
        super hostname, :manipulatord
      end

      def do_status
        # ManipulatordProxy does not currently support a STATUS command
        Thread.new do
          begin
            XBarrier.instance.wait
            @status_mode = nil
            @status_auto = nil
            @status_debug = nil
            XBarrier.instance.wait
          end
        end
      end

      def dummy_mode mode
        # ManipulatordProxy does not currently support a MODE command
        Thread.new do
          begin
            XBarrier.instance.wait
            @mode_error = nil
            @mode_message = nil
            XBarrier.instance.wait
          end
        end
      end

      def do_mode mode
        dummy_mode mode
      end

      def ascend_mode mode
        dummy_mode mode
      end

      def descend_mode mode
        dummy_mode mode
      end

      def do_auto auto
        # ManipulatordProxy does not currently support a AUTO command
        Thread.new do
          begin
            XBarrier.instance.wait
            @auto_error = nil
            @auto_message = nil
            XBarrier.instance.wait
          end
        end
      end
    end


    class CxxxdProxy < Proxy
    end


    class CmondProxy < CxxxdProxy
      def initialize hostname
        super hostname, :cmond
      end
    end


    class CpeerdProxy < CxxxdProxy
      def initialize hostname
        super hostname, :cpeerd
      end
    end


    class CrepdProxy < CxxxdProxy
      def initialize hostname
        super hostname, :crepd
      end
    end

  end
end
