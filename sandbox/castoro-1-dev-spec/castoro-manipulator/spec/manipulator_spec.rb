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

require File.dirname(__FILE__) + '/spec_helper.rb'

require "etc"
require "tmpdir"

describe Castoro::Manipulator::Manipulator do
  before do
    # only root user is executable this spec.
    raise RuntimeError, "*** Please execute by root user" unless Process.uid == 0

    # Precondition.
    # - exists castoro:castoro user.
    @user  = "castoro"
    @group = "castoro"
    @uid   = Etc.getpwnam(@user).uid
    @gid   = Etc.getgrnam(@group).gid

    @times_of_start_stop = 10

    @tempdir = Dir.mktmpdir

    @c = Castoro::Manipulator::Manipulator::DEFAULT_SETTINGS
    @c["base_directory"] = @tempdir
    @l = Logger.new(nil)

    @m = Castoro::Manipulator::Manipulator.new(@c, @l)
  end

  it "should not be alive" do
    @m.alive?.should == false
  end

  context "when start" do
    before do
      @m.start
    end

    it "should be alive" do
      @m.alive?.should == true
    end

    it "UNIX socket should opened" do
      cmd = Castoro::Protocol::Command::Nop.new
      res = UNIXSocket.open(@c["socket"]) { |sock|
        sock.write cmd.to_s
        Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
      }

      res.should == Castoro::Protocol::Response::Nop.new(nil)
    end

    it "should not be able to start" do
      Proc.new {
        @m.start
      }.should raise_error(Castoro::Manipulator::ManipulatorError)
    end

    it "should be able to accept mkdir" do
      dir = File.join(@tempdir, "foo/bar/baz")
      cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, @group, dir)

      # send mkdir packet.
      UNIXSocket.open(@c["socket"]) { |sock|
        sock.write cmd.to_s
        Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
      }.should == Castoro::Protocol::Response::Mkdir.new(nil)

      # check created directory.
      File.directory?(dir).should == true
      stat = File.stat(dir)
      (stat.mode & 0777).should == 0755
      stat.uid.should == @uid
    end

    it "should be able to accept move" do
      src = File.join(@tempdir, "foo/bar/baz")
      dst = File.join(@tempdir, "hoga/fuga")
      cmd = Castoro::Protocol::Command::Mv.new(0555, @user, @group, src, dst)

      FileUtils.mkdir_p src
      FileUtils.touch File.join(src, "qux")
      FileUtils.chmod_R 0700, src

      # send mkdir packet.
      UNIXSocket.open(@c["socket"]) { |sock|
        sock.write cmd.to_s
        Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
      }.should == Castoro::Protocol::Response::Mv.new(nil)

      # check created directory.
      File.directory?(dst).should == true
      stat = File.stat(dst)
      (stat.mode & 0777).should == 0555
      stat.uid.should == @uid
      stat.gid.should == @gid

      File.file?(File.join(dst, "qux")).should == true
      stat = File.stat(File.join(dst, "qux"))
      (stat.mode & 0777).should == (0555 & 0666) # a execution permission is not added to file.
      stat.uid.should == @uid
      stat.gid.should == @gid
    end

    it "should be able to accept mkdir and move request" do
      source    = File.join(@tempdir, "foo/bar/baz")
      dest      = File.join(@tempdir, "hoge/fuga")

      mkdir_cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, @group, source)
      move_cmd  = Castoro::Protocol::Command::Mv.new(0555, "root", @group, source, dest)

      # send mkdir packet.
      UNIXSocket.open(@c["socket"]) { |sock|
        sock.write mkdir_cmd.to_s
        Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
      }.should == Castoro::Protocol::Response::Mkdir.new(nil)

      # check created directory.
      File.directory?(source).should == true
      stat = File.stat(source)
      (stat.mode & 0777).should == 0755
      stat.uid.should == @uid
      stat.gid.should == @gid

      # create files in created directory.
      files = {
        "file1" => { :mode => 0755, :uid => @uid, :gid => @gid },
        "file2" => { :mode => 0777, :uid => 0   , :gid => @gid },
        "file3" => { :mode => 0555, :uid => @uid, :gid => 0 },
        "file4" => { :mode => 0660, :uid => 0   , :gid => 0 },
      }
      files.each { |k, v|
        path = File.join(source, k)
        FileUtils.touch(path)
        FileUtils.chmod v[:mode], path
        FileUtils.chown v[:uid], v[:gid], path
      }

      # send mv packet.
      UNIXSocket.open(@c["socket"]) { |sock|
        sock.write move_cmd.to_s
        Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
      }.should == Castoro::Protocol::Response::Mv.new(nil)

      # check created directory.
      File.directory?(dest).should == true
      stat = File.stat(dest)
      (stat.mode & 0777).should == 0555
      stat.uid.should == 0
      stat.gid.should == @gid

      # check files.
      files.each { |k, v|
        path = File.join(dest, k)

        File.file?(path).should == true
        stat = File.stat(path)
        (stat.mode & 0777).should == (0555 & 0666) # a execution permission is not added to file.
        stat.uid.should == 0
        stat.gid.should == @gid
      }
      
    end

    describe "MKDIR request." do

      context "when directory already exists." do
        before do
          FileUtils.mkdir_p File.join(@tempdir, "foo/bar/baz")
        end

        it "The directory should be able to be detected already existing" do
          src = File.join(@tempdir, "foo/bar/baz")
          cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, @group, src)
          res = Castoro::Protocol::Response::Mkdir.new({
            "code" => "Castoro::Manipulator::ManipulatorError",
            "message" => "directory already exist.",
          })

          # send mkdir packet.
          UNIXSocket.open(@c["socket"]) { |sock|
            sock.write cmd.to_s
            Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
          }.should == res
        end

        after do
          if File.directory? File.join(@tempdir, "foo/bar/baz")
            FileUtils.rmdir File.join(@tempdir, "foo/bar/baz")
          end
        end
      end

      it "relative path should be able to detected." do
        # chdir
        Dir.chdir @tempdir

        src = "foo/bar/baz"
        cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, @group, src)
        res = Castoro::Protocol::Response::Mkdir.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "relative path cannot set to be dir.",
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

      it "invalid direcotry should be able to be detected." do
        src = "/unknown/base/directory"
        cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, @group, src)
        res = Castoro::Protocol::Response::Mkdir.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "Invalid directory - /unknown/base/directory"
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end
  
      it "unknown user should be able to be detected." do
        src = File.join(@tempdir, "foo/bar/baz")
        cmd = Castoro::Protocol::Command::Mkdir.new(0755, "unknownuser", @group, src)
        res = Castoro::Protocol::Response::Mkdir.new({
          "code" => "ArgumentError",
          "message" => "can't find user for unknownuser"
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end
  
      it "unknown group should be able to be detected." do
        src = File.join(@tempdir, "foo/bar/baz")
        cmd = Castoro::Protocol::Command::Mkdir.new(0755, @user, "unknowngroup", src)
        res = Castoro::Protocol::Response::Mkdir.new({
          "code" => "ArgumentError",
          "message" => "can't find group for unknowngroup"
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

    end

    describe "MV request." do
      before do
        FileUtils.mkdir_p File.join(@tempdir, "foo/bar/baz")
      end

      context "when source directory not found" do
        before do
          FileUtils.rmdir File.join(@tempdir, "foo/bar/baz")
        end

        it "The directory should be able to be detected not existing" do
          src = File.join(@tempdir, "foo/bar/baz")
          dst = File.join(@tempdir, "hoge/fuga")
          cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
          res = Castoro::Protocol::Response::Mv.new({
            "code" => "Castoro::Manipulator::ManipulatorError",
            "message" => "source path not exist.",
          })

          # send mkdir packet.
          UNIXSocket.open(@c["socket"]) { |sock|
            sock.write cmd.to_s
            Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
          }.should == res
        end
      end

      context "when dest already exists." do
        before do
          FileUtils.mkdir_p File.join(@tempdir, "hoge/fuga")
        end

        it "The directory should be able to be detected already existing" do
          src = File.join(@tempdir, "foo/bar/baz")
          dst = File.join(@tempdir, "hoge/fuga")
          cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
          res = Castoro::Protocol::Response::Mv.new({
            "code" => "Castoro::Manipulator::ManipulatorError",
            "message" => "dest path already exist.",
          })

          # send mkdir packet.
          UNIXSocket.open(@c["socket"]) { |sock|
            sock.write cmd.to_s
            Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
          }.should == res
        end

        after do
          if File.directory? File.join(@tempdir, "hoge/fuga")
            FileUtils.rmdir File.join(@tempdir, "hoge/fuga")
          end
        end
      end

      it "relative source path should be able to detected." do
        # chdir
        Dir.chdir @tempdir

        src = "foo/bar/baz"
        dst = File.join(@tempdir, "hoge/fuga")
        cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "relative path cannot set to be source.",
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

      it "invalid source direcotry should be able to be detected." do
        src = "/unknown/base/directory"
        dst = File.join(@tempdir, "hoge/fuga")
        cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "Invalid source directory - /unknown/base/directory"
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

      it "relative dest path should be able to detected." do
        # chdir
        Dir.chdir @tempdir

        src = File.join(@tempdir, "foo/bar/baz")
        dst = "hoge/fuga"
        cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "relative path cannot set to be dest.",
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

      it "invalid dest direcotry should be able to be detected." do
        src = File.join(@tempdir, "foo/bar/baz")
        dst = "/unknown/base/directory"
        cmd = Castoro::Protocol::Command::Mv.new(0755, @user, @group, src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "Castoro::Manipulator::ManipulatorError",
          "message" => "Invalid dest directory - /unknown/base/directory"
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end
  
      it "unknown user should be able to be detected." do
        src = File.join(@tempdir, "foo/bar/baz")
        dst = File.join(@tempdir, "hoge/fuga")
        cmd = Castoro::Protocol::Command::Mv.new(0755, "unknownuser", @group, src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "ArgumentError",
          "message" => "can't find user for unknownuser",
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end
  
      it "unknown group should be able to be detected." do
        src = File.join(@tempdir, "foo/bar/baz")
        dst = File.join(@tempdir, "hoge/fuga")
        cmd = Castoro::Protocol::Command::Mv.new(0755, @user, "unknowngroup", src, dst)
        res = Castoro::Protocol::Response::Mv.new({
          "code" => "ArgumentError",
          "message" => "can't find group for unknowngroup",
        })
  
        # send mkdir packet.
        UNIXSocket.open(@c["socket"]) { |sock|
          sock.write cmd.to_s
          Castoro::Protocol.parse(IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil)
        }.should == res
      end

      after do
        if File.directory? File.join(@tempdir, "foo/bar/baz")
          FileUtils.rmdir File.join(@tempdir, "foo/bar/baz")
        end
      end
    end

    context "when stop" do
      before do
        @m.stop
      end

      it "should not be alive" do
        @m.alive?.should == false
      end

      it "UNIX socket should closed" do
        Proc.new {
          res = UNIXSocket.open(@c["socket"]) { |sock|
            sock.write '["1.1","C","NOP",{}]' + "\r\n"
            IO.select([sock], nil, nil, 5.0) ? sock.recv(1024) : nil
          }
        }.should raise_error(Errno::ECONNREFUSED)
      end

      it "should not be able to stop" do
        Proc.new {
          @m.stop
        }.should raise_error(Castoro::Manipulator::ManipulatorError)
      end
    end
  end

  it "should be able to start > stop > start > .." do
    @times_of_start_stop.times {
      @m.start
      @m.alive?.should == true
      @m.stop
      @m.alive?.should == false
    }
  end

  after do
    @m.stop if @m.alive?
    @m = nil

    FileUtils.remove_entry_secure @tempdir
  end
end

