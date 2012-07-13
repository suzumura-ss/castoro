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

require 'singleton'
require 'etc'
require 'digest/md5'
require 'castoro-pgctl/configurations_pgctl'

module Castoro
  module Peer

    class Password
      include Singleton

      def initialize
        @pw = PasswordFile.new
      end

      def change
        puts "Changing password for the command pgctl."
        @pw.changable?

        unless @pw.empty?
          x = read_password "(current) pgctl password: "
          @pw.verify( x ) or raise AuthenticationError, "Password does not match. Authentication failed."
        end

        a = read_password "New pgctl password: "
        b = read_password "Retype new pgctl password: "
        a == b or raise AuthenticationError, "Sorry, passwords do not match."

        @pw.store a
        puts "pgctl password has been successfully changed."
      end

      def authenticate
        n = 0  # the number of attempts
        m = Configurations::Pgctl.instance.pgctl_password_attemptlimit

        loop do
          x = read_password "Password: "
          @pw.verify( x ) and return true
          n = n + 1
          n < m or raise AuthenticationError, "Password does not match. Authentication failed."
          puts "Sorry, try again."
        end
        false
      end

      def empty?
        @pw.empty?
      end

      private

      def read_password s
        print s

        # some terminal emulators via ssh remote login has a setting with -echo 
        # from the beginning. so tries to preserve it.
        s =`/usr/bin/stty -a`
        m = s.match /\W(-?echo)\W/
        c = (m.nil?) ? "echo" : m[1]

        system "stty raw -echo"
        x = gets
        puts ""
        return x.chomp
      ensure
        system "stty -raw #{c}"
      end


      class PasswordFile
        def initialize
          @file = Configurations::Pgctl.instance.pgctl_password_file
          @back = Configurations::Pgctl.instance.pgctl_password_backupfile
          @digest = Digest::MD5.new
        end

        def changable?
          if File.exist? @file
            File.writable?( @file ) or raise AuthenticationError, "The password file is not writable: #{@file}"
          else
            dir = File.dirname @file
            File.writable?( dir ) or raise AuthenticationError, "The password file #{@file} does not exist, but the directory for it is not writable: #{dir}  If you do not want to make the #{dir} writable, you may create #{@file} and make it writable, instead."
          end
          if File.exist? @back
            File.writable?( @back ) or raise AuthenticationError, "The password backup file is not writable: #{@back}"
          else
            dir = File.dirname @back
            File.writable?( dir ) or raise AuthenticationError, "The password file #{@back} does not exist, but the directory for it is not writable: #{dir}  If you do not want to make the #{dir} writable, you may create #{@back} and make it writable, instead."
          end
        end

        def empty?
          verify ""
        end

        def verify x
          if x == ""
            not File.exist?( @file ) or File.size( @file ) == 0 or match( x )
          else
            match x 
          end
        end

        def match x
          File.open( @file, "r" ) do |f|
            y = f.gets
            m = y.match( /\A(\w+)/ ) and return ( m[1] == @digest.hexdigest( x ) )
          end
        end

        def store x
          changable?
          dir = File.dirname @file
          mode = Configurations::Pgctl.instance.pgctl_password_filemode
          if File.exist? @file
            if File.stat( @file ).uid == Process.euid and File.writable?( dir )
              File.rename @file, @back
            else
              b = File.exist? @back
              copy @file, @back
              File.chmod mode, @back unless b
            end
          end

          f = File.exist? @file
          write @file, x
          File.chmod mode, @file unless f
        end

        def write file, x
          File.open( file, "w" ) do |f|
            data = @digest.hexdigest x
            user = Etc.getpwuid( Process.euid ).name
            time = Time.now
            f.puts "#{data} # Created by #{user} #{time}"
          end
        end

        def copy src, dst
          File.open( src, "rb" ) do |s|
            File.open( dst, "wb" ) do |d|
              IO.copy_stream s, d
            end
          end
        end
      end

    end
  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      Configurations::Pgctl.file = "../../etc/castoro/pgctl.conf-sample-en.conf"

      Password.instance

      p [ "Password.instance.empty?", Password.instance.empty? ]

      Password.instance.change

      p Password.instance.authenticate
    end
  end
  
end

__END__



    x = Password.new "./x"
    a = x.xxx
    puts ""
    p a

    end

~
$ /usr/bin/passwd
Changing password for user akiyama.
Changing password for akiyama
(current) UNIX password: 
passwd: Authentication token manipulation error

16:28:29 Mon Jul 09  sdbext000  akiyama
~
$ /usr/bin/passwd
Changing password for user akiyama.
Changing password for akiyama
(current) UNIX password: 
New UNIX password: 
BAD PASSWORD: it is too short
New UNIX password: 
BAD PASSWORD: it is WAY too short
New UNIX password: 
BAD PASSWORD: it is WAY too short
passwd: Authentication token manipulation error

16:28:47 Mon Jul 09  sdbext000  akiyama
~
$ /usr/bin/passwd
Changing password for user akiyama.
Changing password for akiyama
(current) UNIX password: 
New UNIX password: 
BAD PASSWORD: is too similar to the old one
New UNIX password: 
Retype new UNIX password: 


16:29:36 Mon Jul 09  sdbext000  akiyama
~
$ 
          a = read_password
~
$ /usr/bin/passwd
Changing password for user akiyama.
Changing password for akiyama
(current) UNIX password: 
New UNIX password: 
Retype new UNIX password: 
Sorry, passwords do not match.
New UNIX password: 
BAD PASSWORD: it is WAY too short
New UNIX password: 
Retype new UNIX password: 
Sorry, passwords do not match.
passwd: Authentication information cannot be recovered

16:35:18 Mon Jul 09  sdbext000  akiyama
~


$ /usr/bin/sudo /bin/bash
Password: xxx

Sorry, try again.
Password: xxx

Sorry, try again.
Password: xxx

Sorry, try again.
sudo: 3 incorrect password attempts

$ /usr/bin/ssh stdext000 -l xxx
Password: xxx

Password: xxx

Password: xx

Permission denied (gssapi-keyex,gssapi-with-mic,publickey,keyboard-interactive).
