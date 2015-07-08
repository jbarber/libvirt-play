## Notes

* My version of libvirt-ruby (ruby-libvirt-0.5.2-3.fc20.x86_64) appears to be
  missing lots of the constants, so I've defined the ones I need near where
  they are used

* The event handlers look as though they could be interesting to noticing
  events without polling, but also look quite hairy to use. [Example usage](http://libvirt.org/ruby/examples/event_test.rb)

* iptables filters can be manipulated from libvirt, which is funky:

    * http://libvirt.org/ruby/examples/nwfilter.rb
    * http://libvirt.org/formatnwfilter.html
