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

rspec_version = :new
begin
  require 'rspec'
rescue LoadError
  begin
    require 'rubygems' unless ENV['NO_RUBYGEMS']
    require 'rspec'
  rescue LoadError
    require 'spec'
    rspec_version = :old
  end
end

begin
  if rspec_version == :new
    require 'rspec/core/rake_task'
  else
    require 'spec/rake/spectask'
  end
rescue LoadError
  puts <<-EOS
To use rspec for testing you must install rspec gem:
    gem install rspec
EOS
  exit(0)
end

desc "Run the specs under spec/models"
if rspec_version == :new then
  RSpec::Core::RakeTask.new do |t|
    t.pattern = "spec/**/*_spec.rb"
    t.rspec_opts = ["-cfs"]
  end
else
  Spec::Rake::SpecTask.new do |t|
    t.pattern = "spec/**/*_spec.rb"
    t.spec_opts = ['--options=' "spec/spec.opts"]
    t.spec_opts = ["-cfs"]
    end
end

