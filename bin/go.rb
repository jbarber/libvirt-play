require 'HV'
require 'pp'
require 'erb'
require 'rexml/document'

class Base
  def initialize(options = {})
    options.each do |k, v|
      self.send("#{k}=", v)
    end
  end

  def configuration(path)
    template = File.read(path)
    ERB.new(template, nil, '%').result(binding)
  end
end

class Machine < Base
  attr_accessor :name, :ip, :memory, :cpus, :image, :conn, :password, :network, :mac
  Libvirt::VIR_DOMAIN_AFFECT_CURRENT = 0

  def mac
    bytes = [0x52, 0x54, 0x00, Array.new(3).map { rand(256) }].flatten
    @mac ||= bytes.map { |d| sprintf('%02x', d) }.join(':')
  end

  def dom
    @conn.lookup_domain_by_name(name)
  end

  def start
    dom.create
  end

  def destroy
    dom.destroy
  end

  def xml
    REXML::Document.new(dom.xml_desc)
  end

  def macs
    xml.elements.each('domain/devices/interface/mac') { |d| d }.map { |d| d.attribute('address').value }
  end

  def vnc
    xml.elements.each("domain/devices/graphics[@type='vnc']") { |e|
      e
    }.map { |e|
      e.attribute('port')
    }
  end

  # WARNING: This doesn't change the xml from dom.xml_desc so make sure you
  # remember the new password
  def set_vnc_password(password)
    # TODO: handle multiple vnc devices?
    vnc = REXML::XPath.first(xml, "domain/devices/graphics[@type='vnc']")
    vnc.add_attribute('passwd', password)
    dom.update_device(
      vnc.to_s,
      Libvirt::VIR_DOMAIN_AFFECT_CURRENT,
    )
  end

  def screenshot
    stream   = conn.stream
    mimetype = dom.screenshot(stream, 0)
    img      = ''

    stream.recvall(img) do |data, opaque|
      opaque.concat(data)
      data.length
    end

    stream.finish
    conn.close

    img.length === '' ? nil : img
  end
end

class Network < Base
  attr_accessor :name, :bridge, :conn
  Libvirt::NETWORK_UPDATE_COMMAND_DELETE = 2
  Libvirt::NETWORK_UPDATE_COMMAND_ADD_LAST = 3
  Libvirt::NETWORK_SECTION_IP_DHCP_HOST = 4
  Libvirt::NETWORK_UPDATE_AFFECT_CURRENT = 0

  def dhcp_xml(machine)
    m = machine
    %Q(<host mac='#{m.macs.first}' name='#{m.name}' ip='#{m.ip}' />)
  end
  private :dhcp_xml

  def dhcp_add (machine)
    conn.lookup_network_by_name(name).update(
      Libvirt::NETWORK_UPDATE_COMMAND_ADD_LAST,
      Libvirt::NETWORK_SECTION_IP_DHCP_HOST,
      -1,
      dhcp_xml(machine),
      Libvirt::NETWORK_UPDATE_AFFECT_CURRENT
    )
  end

  def dhcp_del (machine)
    conn.lookup_network_by_name(name).update(
      Libvirt::NETWORK_UPDATE_COMMAND_DELETE,
      Libvirt::NETWORK_SECTION_IP_DHCP_HOST,
      -1,
      dhcp_xml(machine),
      Libvirt::NETWORK_UPDATE_AFFECT_CURRENT
    )
  end
end

lv = HV.new()
lv.conn()

n = Network.new(
  :name => 'test',
  :bridge => 'virbr3',
  :conn => lv.conn
)

m = Machine.new(
  :name     => 'test',
  :memory   => 1024,
  :cpus     => 2,
  :image    => '/home/jbarber/.vagrant.d/tmp/storage-pool/test.img',
  :conn     => lv.conn,
  :ip       => '192.168.123.5',
  :password => 'bar',
  :network  => n.name,
)

# Transient domains are destroyed+undefined when they are stopped, which means
# we don't have to remove them ourselves
transient = true

# Add the network configuration if not already present
unless lv.conn.list_networks.any? { |net| net == n.name }
  lv.create_network(n.configuration('resources/network.erb'))
end

# lookup_domain_by_name() throws Libvirt::RetrieveError if the domain doesn't
# exist instead of returning something useful like nil
#begin
#  lv.conn.lookup_domain_by_name(m.name)
#rescue Libvirt::RetrieveError => error
#  lv.create_domain(m.configuration('resources/domain.erb'))
#end

# Add the domain configuration if not present
unless lv.list_domains.any? { |d| c.lookup_domain_by_id(d).name == m.name }
  if transient
    lv.create_transient_domain(m.configuration('resources/domain.erb'))
  else
    lv.create_domain(m.configuration('resources/domain.erb'))
  end
end

# Add DHCP entry before the machine starts to make sure the entry isn't missing
# when it does DHCP
begin
  n.dhcp_add(m)
rescue Libvirt::Error => error
  puts error
end

if transient
  m.dom.resume
else
  m.start
end

#puts m.screenshot
#m.set_vnc_password('foo')

exit 0
m.destroy
n.dhcp_del(m)
