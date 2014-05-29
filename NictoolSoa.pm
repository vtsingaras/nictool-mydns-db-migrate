package NictoolSoa;

use strict;
use warnings;
use Class::Struct;

struct(
	nt_zone_id => '$', #100
	nt_group_id => '$', #1
	zone => '$',
	mailaddr => '$',
	description => '$',
	serial => '$',
	refresh => '$',
	retry => '$',
	expire => '$',
	minimum => '$',
	ttl => '$',
	location => '$',
	last_modified => '$', #timestamp
	deleted => '$' #0
);

1;
