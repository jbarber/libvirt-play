require 'pp'
require 'state_machine'

class Machine
    state_machine :initial => :waiting do
        event :init do
            transition :waiting => :initializing
        end

        event :initialized do
            transition :initializing => :initialized
        end

        event :boot do
            transition :initialized => :booting
        end

        event :booted do
            transition :booting => :booted
        end

        event :destroy do
            transition all - [:destroyed] => :destroyed
        end

        before_transition :initialized => :booting do |machine, trans|
            puts "first"
            false
        end

        before_transition :initialized => :booting do |machine, trans|
            puts "second"
            pp machine, trans
            false
        end

        before_transition :booting => :booted do |machine, trans|
            pp machine, trans
            throw :halt
        end

        after_failure :on => :booted, :do => :log

        after_failure do |m, trans|
            print "Generic failure handler: "
            pp trans
        end
    end

    def log(trans)
        print "Specific failure handler: "
        pp trans
    end
end

m = Machine.new
m.init
m.initialized
m.boot
m.booted
#pp m.state_paths
#
class Klass
    include Singleton
    attr_accessor :a

    def initialize
        puts "called"
        @a = 1
    end


    def add()
        @a += 1
    end
end

b = Klass.instance
pp b.add()
c = Klass.instance
pp c.add
pp b.add
