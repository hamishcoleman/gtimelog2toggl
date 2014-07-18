use Test::More;

BEGIN {
    use_ok('Event');
}

my $event;
$event = Event->new();
isa_ok($event,'Event', 'Create event object');
is($event->as_string(),undef, 'show an empty object');

use DateTime::Format::ISO8601;
my $dt1= DateTime::Format::ISO8601->parse_datetime('2014-07-01T09:00:00+01:00');
my $dt2= DateTime::Format::ISO8601->parse_datetime('2014-07-01T09:30:00+01:00');

isa_ok($event->set_start($dt1),'Event', 'set start datetime');
is($event->start,$dt1, 'get start');
is($event->minutes,undef, 'get minutes with only start set');
is($event->as_string(),undef, 'show an object with just starttime set');

isa_ok($event->set_finish($dt2),'Event', 'set finish datetime');
is($event->finish,$dt2, 'get finish');

is($event->minutes,30, 'get minutes with only start and finish set');

$event = Event->new();
isa_ok($event->set_finish($dt2),'Event', 'set finish datetime');
is($event->minutes,undef, 'get minutes with only finish set');

# only handle missing minutes, we could handle any one of the three values
# missing

$event = Event->new();
isa_ok($event->set_minutes(30),'Event', 'set minutes length');
is($event->minutes(),30, 'get minutes length');
is($event->as_string(),undef, 'show an object with just minutes set');

$event->set_start($dt1);

is($event->as_string(), '2014-07-01T09:00:00+0100, 30m, ', 'show event');

isa_ok($event->set_description('A Description'),'Event', 'set description');
is($event->description,'A Description', 'get description');

is($event->as_string(), '2014-07-01T09:00:00+0100, 30m, A Description', 'show event with description');

done_testing();
