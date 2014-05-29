package NictoolRR;

use strict;
use warnings;
use Class::Struct;

struct( 
	nt_zone_record_id => '$',
	nt_zone_id => '$',
	name => '$',
	ttl => '$',
	description => '$',
	type_id => '$',
	address => '$',
	weight => '$',
	priority => '$',
	other => '$',
	location => '$',
	timestamp => '$',
	deleted => '$'
);
	
1;
