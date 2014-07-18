use Test::More;

BEGIN {
    use_ok('Gtimelog');
}

use File::Spec;
my $testdir = (File::Spec->splitpath($0))[1];

my $gtimelog;
$gtimelog = Gtimelog->new();
isa_ok($gtimelog,'Gtimelog', 'Create object');

is($gtimelog->virtual_midnight->in_units('minutes'),120,"get virtual midnight");

use DateTime::Format::ISO8601;
my $dt= DateTime::Format::ISO8601->parse_datetime('2014-07-01T09:00:00');
is($gtimelog->_dt2vmidnight($dt),'2014-07-02T02:00:00',"Check vmidnight");

$dt= DateTime::Format::ISO8601->parse_datetime('2014-07-01T01:00:00');
is($gtimelog->_dt2vmidnight($dt),'2014-07-01T02:00:00',"Check vmidnight");

#isa_ok($gtimelog->set_midnight($midnight),'Gtimelog', 'set midnight');
#is($gtimelog->midnight,, 'get midnight');

is($gtimelog->events(),undef, 'get events with no filename');

# FIXME - this will require fixing _load_events to not die()
#$gtimelog->set_filename('file not found');
#is($gtimelog->events(),undef, 'get events with file not found error');

my $filename = File::Spec->catfile($testdir,'Gtimelog.test1.txt');
isa_ok($gtimelog->set_filename($filename),'Gtimelog', 'set filename');
is($gtimelog->filename,$filename, 'get filename');

my @events;
@events = $gtimelog->events();
is(scalar(@events),4, 'count events from test1');

is($events[0]->as_string(),'2014-07-07T09:00:00+0100, 30m, Catchup: BSC','Check event 1');
is($events[1]->as_string(),'2014-07-07T09:30:00+0100, 102m, Other:','Check event 2');
is($events[2]->as_string(),'2014-07-07T11:12:00+0100, 42m, Catchup: Nick','Check event 3');
is($events[3]->as_string(),'2014-07-08T09:15:00+0100, 30m, Test: Events','Check event 4');

# For the coverage, check the events are cached
$gtimelog->set_filename('file not found');
@events = $gtimelog->events();
is(scalar(@events),4, 'count events from test1');


done_testing();
