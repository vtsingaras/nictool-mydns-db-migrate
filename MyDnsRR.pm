package MyDnsRR;

use strict;
use warnings;
use Class::Struct;

struct( 
	id => '$',
	zone => '$',
	name => '$',
	type => '$',
	data => '$',
	aux => '$',
	ttl => '$',
	comments => '$',
	lastupdater => '$',
	timestamp => '$'
);
	
1;
