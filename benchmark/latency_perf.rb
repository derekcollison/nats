# Copyright 2010-2018 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'optparse'

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'nats/client'

$loop = 10000
$hash = 1000
$sub  = 'test'

STDOUT.sync = true

parser = OptionParser.new do |opts|
  opts.banner = "Usage: latency_perf [options]"

  opts.separator ""
  opts.separator "options:"

  opts.on("-n ITERATIONS", "iterations to expect (default: #{$loop})") { |iter| $loop = iter.to_i }
end

parser.parse(ARGV)
$drain = $loop

trap("TERM") { exit! }
trap("INT")  { exit! }

NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

NATS.start do

  def done
    ms = "%.2f" % (((Time.now-$start)/$loop)*1000.0)
    puts "\nTest completed : #{ms} ms avg request/response latency\n"
    NATS.stop
  end

  def send_request
    s = NATS.request('test') {
      $drain-=1
      if $drain == 0
        done
      else
        send_request
        printf('+') if $drain.modulo($hash) == 0
      end
      NATS.unsubscribe(s)
    }
  end

  s_conn = NATS.connect
  s_conn.subscribe('test') do |msg, reply|
    s_conn.publish(reply)
  end


  # Send first request when we are connected with subscriber
  s_conn.on_connect {
    puts "Sending #{$loop} request/responses"
    $start = Time.now
    send_request
  }

end
