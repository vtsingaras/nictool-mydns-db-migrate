nictool-mydns-db-migrate
========================

Perl utility that handles the process of MyDNS -> Nictool DB migration.

USAGE

Edit the script and provide it with the correct nsid of the server that all zones will be imported to (found in the nictool database under nt_nameservers) and correct DSN strings.
If you suspect your MyDNS database to be contaminated with orphaned records then before running the script create an empty zone in Nictool with domain: "orphaned.records.tld"

TROUBLESHOOTING

If the import errors out then login to MySQL and do: delete from nt_zone where nt_zone_id > $ZONEID ($ZONEID = id of last correct zone) and delete from nt_zone_record where nt_zone_record_id > $RRID (id of last correct resource record)
