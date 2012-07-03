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

require 'rubygems'
require 'fileutils'

module Castoro
  module ClientLocal
    attr_accessor :basedir
    @local_opened = false

  private
    def basepath(key, mode)
      "#{@basedir}/#{key.type}/baskets/#{mode}"
    end
    def basketkey_to_path(key, mode)
      "#{basepath(key, mode)}/#{key.to_s}"
    end

  public
    def open
      FileUtils.mkdir_p("#{@basedir}/trash")
      @local_opened = true
      @basedir ||= '/expdsk'
    end

    def close
      @local_opened = false
    end

    def opened?; @local_opened; end
    def closed?; !opened?; end

    def http_port=(port)
      @http_port = (port==80)? "" : ":#{port}"
    end

    def create key, hints = {}
      raise ClientError, "Client is not opened." unless opened?
      raise ClientError, "It is necessary to specify the block argument." unless block_given?

      key = BasketKey.parse(key) if key.kind_of? String
      host = "localhost#{@http_port}"
      path = basketkey_to_path(key, 'a')
      raise ClientError, "create command failed - BasketAlreadyExist(#{key.to_s}, localhost." if File.directory?(path)
      path = basketkey_to_path(key, 'w')
      raise ClientError, "create command failed - BasketAlreadyExist(#{key.to_s}, localhost." if File.directory?(path)
      begin
        FileUtils.mkdir_p(path)
      rescue Errno::EACCES=>e
        raise ClientError, "create command failed - #{e.inspect}, localhost."
      end
        
      begin
        yield host, path
      rescue =>e
        FileUtils.rm_rf(path)
        raise e
      end
      FileUtils.mkdir_p(basepath(key, 'a'))
      FileUtils.mv(path, basketkey_to_path(key, 'a'))
    end

    def get key
      raise ClientError, "Client is not opened." unless opened?

      key = BasketKey.parse(key) if key.kind_of? String
      path = basketkey_to_path(key, 'a')
      raise ClientTimeoutError, "get command failed - ClientTimeoutError(#{key.to_s}), localhost." unless File.directory?(path)
      {"localhost#{@http_port}"=>path}
    end

    def delete key
      raise ClientError, "Client is not opened." unless opened?

      key = BasketKey.parse(key) if key.kind_of? String
      path_a = basketkey_to_path(key, 'a')
      path_d = basketkey_to_path(key, 'd')
      begin
        FileUtils.mkdir_p(basepath(key, 'd'))
        FileUtils.rm_rf(path_d)
      rescue Errno::EACCES=>e
        raise ClientError, "delete command failed - #{e.inspect}, localhost."
      end
      FileUtils.mv(path_a, path_d) rescue nil
      nil
    end
  end
end
