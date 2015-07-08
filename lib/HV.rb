require 'libvirt'

class HV
    #include Singleton

    def conn
       @conn ||= Libvirt::open('qemu:///system')
       # FIXME: alive? doesn't return false if libvirtd is restarted
       unless @conn.alive?
           @conn = Libvirt::open('qemu:///system')
       end
       @conn
    end

    # The domain is started in a pause state. Call domain.resume to make
    # it run
    Libvirt::VIR_DOMAIN_START_PAUSED = 1
    def create_transient_domain(xml)
        @conn.create_domain_xml(xml, Libvirt::VIR_DOMAIN_START_PAUSED)
    end

    def create_domain(xml)
        @conn.define_domain_xml(xml)
    end

    def create_network(xml)
        @conn.create_network_xml(xml)
    end
end
