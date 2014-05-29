package NictoolNS;

use strict;
use warnings;
use Class::Struct;

struct( 
	nt_nameserver_id => '$',
	nt_group_id => '$',
	name => '$',
	ttl => '$',
	description => '$',
	address => '$',
	logdir => '$', #/var/log
	datadir => '$', #/etc/bind/nictool /etc/bind + ns
	export_format => '$', #bind
	export_interval => '$', #secs
	export_serials => '$', #1
	export_status => '$', #string
	deleted => '$' 		#bool
);

1;
