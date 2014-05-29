package main;

use strict;
use warnings;
use DBI;
use Class::Struct;
use Socket;
use TryCatch;
use Switch;
use MyDnsSoa;
use NictoolSoa;
use MyDnsRR;
use NictoolRR;

our $dbh_nictool = DBI->connect(
	"dbi:mysql:nictool:nictooldbhost:3306",
	"nictooldbuser", "nictooldbpass",
	{ RaiseError => 1, FetchHashKeyName => "NAME_lc" },
) or die $DBI::errstr;

our $dbh_mydns = DBI->connect(
	"dbi:mysql:mydns:mydnsdbhost:3306",
	"mydnsdbuser", "mydnsdbpass",
	{ RaiseError => 1, FetchHashKeyName => "NAME_lc" },
) or die $DBI::errstr;

importMyDnsToNictoolAll();
updateMydnsRrToNictool();

$dbh_nictool->disconnect();
$dbh_mydns->disconnect();

sub importMyDnsToNictoolAll {

	my $st_fetch_soa = $dbh_mydns->prepare("SELECT * FROM soa") or die;
	$st_fetch_soa->execute() or die;

	my @soa_records;    #mydns_struct, nictoolns
	my $row = 0;
	while ( my $soa_row = $st_fetch_soa->fetchrow_hashref() ) {
		my $mydns_soa        = MyDnsSoa->new();
		my $sanitized_origin = $soa_row->{origin};
		chop($sanitized_origin);    #remove trailing dor from mydns FQDN
		$mydns_soa->id( $soa_row->{id} );
		$mydns_soa->origin($sanitized_origin);
		$mydns_soa->ns( $soa_row->{ns} );
		$mydns_soa->mbox( $soa_row->{mbox} );
		$mydns_soa->serial( $soa_row->{serial} );
		$mydns_soa->refresh( $soa_row->{refresh} );
		$mydns_soa->retry( $soa_row->{retry} );
		$mydns_soa->expire( $soa_row->{expire} );
		$mydns_soa->minimum( $soa_row->{minimum} );
		$mydns_soa->ttl( $soa_row->{ttl} );
		$mydns_soa->comments( $soa_row->{comments} );
		$mydns_soa->lastupdater( $soa_row->{lastupdater} );
		$mydns_soa->timestamp( $soa_row->{timestamp} );

		my $nictool_nsid = 4; #EDIT THIS WITH THE CORRECT NSID
#TODO:

		push @{ $soa_records[$row] }, $mydns_soa;
		push @{ $soa_records[$row] }, $nictool_nsid;


		$row++;
	}
	foreach my $soa_and_nsid (@soa_records) {
		my $nictool_zoneid = Nictool::getZoneIdFromName( $soa_and_nsid->[0]->origin );
		my $nictool_nsid = $soa_and_nsid->[1];
		if ( $nictool_zoneid != 0 ) {
			next;
		}
		else {

			#Nictool::createZone($soa_and_nsid); #pass array
			my $nictool_soa = NictoolSoa->new();
			$nictool_soa->zone( $soa_and_nsid->[0]->origin );
			$nictool_soa->mailaddr( $soa_and_nsid->[0]->mbox );
			$nictool_soa->serial( $soa_and_nsid->[0]->serial );
			$nictool_soa->refresh( $soa_and_nsid->[0]->refresh );
			$nictool_soa->retry( $soa_and_nsid->[0]->retry );
			$nictool_soa->expire( $soa_and_nsid->[0]->expire );
			$nictool_soa->minimum( $soa_and_nsid->[0]->minimum );
			$nictool_soa->ttl( $soa_and_nsid->[0]->ttl );
			$nictool_soa->last_modified( $soa_and_nsid->[0]->timestamp );

		   #nictool default values, mydns has no groups, description or location
			$nictool_soa->deleted(0);
			$nictool_soa->nt_group_id(1);
			$nictool_soa->description(undef);
			$nictool_soa->location(undef);

			my $nictool_new_zone_query = "INSERT INTO nt_zone (nt_group_id, zone, mailaddr, description, serial, refresh, retry, expire, minimum, ttl, location, last_modified, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
			my $nictool_new_zone_statement =
			  $dbh_nictool->prepare($nictool_new_zone_query);
			$nictool_new_zone_statement->execute(
				$nictool_soa->nt_group_id, $nictool_soa->zone,
				$nictool_soa->mailaddr,    $nictool_soa->description,
				$nictool_soa->serial,      $nictool_soa->refresh,
				$nictool_soa->retry,       $nictool_soa->expire,
				$nictool_soa->minimum,     $nictool_soa->ttl,
				$nictool_soa->location,    $nictool_soa->last_modified,
				$nictool_soa->deleted
			);
			$nictool_new_zone_statement->finish();
		}

		$nictool_zoneid = Nictool::getZoneIdFromName( $soa_and_nsid->[0]->origin );
		my $nictool_assign_ns_query = "INSERT INTO nt_zone_nameserver (nt_zone_id, nt_nameserver_id) VALUES (?, ?)";
		my $nictool_assign_ns_statement =
		  $dbh_nictool->prepare($nictool_assign_ns_query);
		$nictool_assign_ns_statement->execute( $nictool_zoneid,
			$nictool_nsid );
		$nictool_assign_ns_statement->finish();
	}
	$st_fetch_soa->finish();
}

sub updateMydnsRrToNictool {

	my $st_fetch_mydns_rr = $dbh_mydns->prepare("SELECT * FROM rr") or die;
	$st_fetch_mydns_rr->execute() or die;

	my $mydns_rr;    #mydnsrr_struct
	while ( my $mydns_rr_row = $st_fetch_mydns_rr->fetchrow_hashref() ) {
		my $mydns_rr = MyDnsRR->new();
		$mydns_rr->id( $mydns_rr_row->{id} );    #redundant?
		$mydns_rr->zone( $mydns_rr_row->{zone} );
		$mydns_rr->name( $mydns_rr_row->{name} );
		$mydns_rr->type( $mydns_rr_row->{type} );
		$mydns_rr->data( $mydns_rr_row->{data} );
		$mydns_rr->aux( $mydns_rr_row->{aux} );
		$mydns_rr->ttl( $mydns_rr_row->{ttl} );
		$mydns_rr->comments( $mydns_rr_row->{comments} );
		$mydns_rr->lastupdater( $mydns_rr_row->{lastupdater} );
		$mydns_rr->timestamp( $mydns_rr_row->{timestamp} );

		if ( !defined( $mydns_rr->zone ) ) {
			die $mydns_rr->id;
		}
		my $mydns_origin_name;
		try {
			$mydns_origin_name = MyDns::getZoneOriginFromId( $mydns_rr->zone );
		}catch{
			die $mydns_rr->zone;
		}
		my $nictool_zone_id = Nictool::getZoneIdFromName($mydns_origin_name);

		my $nictool_rr = NictoolRR->new();
		$nictool_rr->nt_zone_id($nictool_zone_id);
		if($mydns_rr->name eq "")
		{
			$nictool_rr->name($mydns_origin_name . ".");
			print "Found empty non-FQDN name for zone: " . $mydns_origin_name . " with mydns_rr_id: " . $mydns_rr->id . " and zone: " . $mydns_rr->zone . ", replacing with " . $nictool_rr->name . "\n";
		#	print $mydns_rr->zone . "\n";
		}else
		{
			$nictool_rr->name( $mydns_rr->name );	
			#print $mydns_rr->name . "\n";
		}
		$nictool_rr->type_id(Nictool::convertMyDnsTypeToNictool( $mydns_rr->type ) );
		$nictool_rr->description( $mydns_rr->comments );
		$nictool_rr->ttl( $mydns_rr->ttl );

		#parse mydns
		my $mydns_data = $mydns_rr->data;
		$nictool_rr->weight( $mydns_rr->aux );
		switch ( $mydns_rr->type ) {
			case "SRV" {
				my @datas = split( /\s/, $mydns_rr->data );
				$nictool_rr->weight($datas[0]);
				$nictool_rr->priority( $mydns_rr->aux );    #weight
				$nictool_rr->other( $datas[1] );     #port
				$nictool_rr->address( $datas[2] );
			}
			else {
				$nictool_rr->address($mydns_data);
			}
		}

		$nictool_rr->location(undef);
		$nictool_rr->timestamp( $mydns_rr->timestamp );
		$nictool_rr->deleted(0);

		my $nictool_new_rr_query = "INSERT INTO nt_zone_record (nt_zone_id, name, ttl, description, type_id, address, weight, priority, other, location, timestamp, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
		my $nictool_new_rr_statement = $dbh_nictool->prepare($nictool_new_rr_query);
		$nictool_new_rr_statement->execute(
			$nictool_rr->nt_zone_id, $nictool_rr->name,
			$nictool_rr->ttl,        $nictool_rr->description,
			$nictool_rr->type_id,    $nictool_rr->address,
			$nictool_rr->weight,     $nictool_rr->priority,
			$nictool_rr->other,      $nictool_rr->location,
			$nictool_rr->timestamp,  $nictool_rr->deleted
		);
		$nictool_new_rr_statement->finish();
	}
}

package Nictool;

use strict;
use warnings;
use diagnostics;
use TryCatch;
use Socket;
use Switch;
use NictoolNS;

sub createNs {
	my @name = @_;

	my $ns = NictoolNS->new();
	$ns->name(@name);
	my $ns_dir = join "", "/etc/bind/", $ns->name;
	mkdir( $ns_dir, 0644 );
	my $user       = getpwnam( getpwuid($<) );
	my $bind_group = getgrnam("bind");
	chown $user, $bind_group, $ns_dir;

	$ns->nt_group_id(1);
	$ns->ttl(86400);
	$ns->description("auto generated during import");
	my $packed_ipv4 = gethostbyname( $ns->name );
	$ns->address( Socket::inet_ntoa($packed_ipv4) );
	$ns->logdir("/var/log/");
	$ns->datadir($ns_dir);
	$ns->export_format("bind");
	$ns->export_interval(120);
	$ns->export_serials(1);
	$ns->export_status("");
	$ns->deleted(0);

	#insert new ns entry
	my $ns_query = "insert into nt_nameserver (nt_group_id, name, ttl, description, address, logdir, datadir, export_format, export_interval, export_serials, export_status, deleted) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ";
	my $ns_statement = $dbh_nictool->prepare($ns_query);
	$ns_statement->execute(
		$ns->nt_group_id,    $ns->name,          $ns->ttl,
		$ns->description,    $ns->address,       $ns->logdir,
		$ns->datadir,        $ns->export_format, $ns->export_interval,
		$ns->export_serials, $ns->export_status, $ns->deleted
	);
	$ns_statement->finish();
}

sub convertMyDnsTypeToNictool {
	my $type = $_[0];

	my $nictool_type_query = "SELECT id FROM resource_record_type WHERE name = ?";
	my $nictool_type_statement = $dbh_nictool->prepare($nictool_type_query);
	$nictool_type_statement->execute($type);
	my $type_id = $nictool_type_statement->fetch()->[0];
	$nictool_type_statement->finish();
	if ( !defined $type_id ) {
		die "Unrecoverable error";
	}
	return $type_id;
}

#TODO: implement insert update select as functions

#Pass the FQDN (do not ommit the trailing dot)

sub getNsIdFromName {
	my @name = @_;

	my $st_soa = $dbh_nictool->prepare("SELECT nt_nameserver_id FROM nt_nameserver WHERE name = ? AND deleted != '1'");
	$st_soa->execute( $name[0] );
	my $ns_id = $st_soa->fetch();

	$st_soa->finish();
	if ( !defined $ns_id ) {
		return 0;
	}
	return $ns_id;
}

sub getZoneIdFromName {
	my $zone_str = $_[0];
	my $st_zone_query = "SELECT nt_zone_id FROM nt_zone WHERE zone = ? AND deleted != '1'";
	my $st_zone = $dbh_nictool->prepare($st_zone_query);
	$st_zone->execute($zone_str);
	my $zone_id;
	try{
		$zone_id = $st_zone->fetch()->[0];
	}catch
	{
		return 0;
	}
	$st_zone->finish();
	if ( !defined $zone_id ) {
		return 0;
		#die $zone_str;
	}
	return $zone_id;
}

sub getAssignedNs {
	my $zoneid = $_[0][0];
	my $get_ns_query = "SELECT nt_nameserver_id FROM nt_zone_nameserver WHERE nt_zone_id = ?";
	my $get_ns_statement = $dbh_nictool->prepare($get_ns_query);
	$get_ns_statement->execute( $zoneid );
	my $ns_id = $get_ns_statement->fetch();
	$get_ns_statement->finish();
	if ( !defined $ns_id ) {
		return 0;
	}
	return $ns_id;
}

package MyDns;

use TryCatch;
use warnings;
use diagnostics;

sub getZoneOriginFromId {
	my @zone_id = @_;

	my $st_zone_origin = $dbh_mydns->prepare("SELECT origin FROM soa WHERE id = ?");
	if ( !defined( $zone_id[0] ) ) {
		print $zone_id[0];
	}
	my $zone_origin;
	try {
	$st_zone_origin->execute( $zone_id[0] );
	}
	catch {
		die "catch st execute";
	}
	try{
		$zone_origin = $st_zone_origin->fetch()->[0];
	}catch
	{
		return "orphaned.records.tld";
	}

	$st_zone_origin->finish();
	if ( !defined $zone_origin ) {
		die $zone_id[0];
	}
	chop($zone_origin);
	return $zone_origin;
}
