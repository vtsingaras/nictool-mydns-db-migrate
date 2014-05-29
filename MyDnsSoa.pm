package MyDnsSoa;

use strict;
use warnings;
use Class::Struct;

struct( 
	id => '$',
	origin => '$',
	ns => '$',
	mbox => '$',
	serial => '$',
	refresh => '$',
	retry => '$',
	expire => '$',
	minimum => '$',
	ttl => '$',
	comments => '$',
	lastupdater => '$',
	timestamp => '$'
);

1;
