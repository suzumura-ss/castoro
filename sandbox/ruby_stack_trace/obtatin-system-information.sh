#! /bin/bash -x

echo $PATH
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

uname -a
ls -l /etc/redhat-release
cat /etc/redhat-release
dmesg | grep CPU 
lspci
/sbin/ifconfig -a

which which
/usr/bin/which gcc
gcc --version
/usr/bin/which strace

/usr/bin/which ruby
/usr/bin/which gem
/usr/bin/which rake
/usr/bin/ruby --version
/usr/local/bin/ruby --version
/usr/local/bin/gem --version
/usr/local/bin/rake --version
/usr/local/bin/gem list

find /usr/local/lib/ruby/gems -type d
tree -d /usr/local/lib/ruby/gems
find /usr/local/lib/ruby/gems -type f -ls | grep castoro-peer
find /usr/local/lib/ruby/gems -type f -ls | grep castoro-pgctl
find /usr/local/lib/ruby/gems -type f -ls | grep castoro-manipulator
find /usr/local/lib/ruby/gems -type f -ls | grep castoro-common

