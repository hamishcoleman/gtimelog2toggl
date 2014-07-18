package Gtimelog;
#
# Routines for opening and using a gtimelog file
#

use FileHandle;
use DateTime::Format::Strptime;
use DateTime::Duration;
use Event;

sub new {
    my ($class) = shift;
    my $self = {};
    bless $self, $class;

    # set default midnight
    #$self->set_midnight( xyzzzy );

    return $self;
}

sub set_filename {
    my ($self) = shift;
    my ($filename) = shift;

    $self->{_filename} = $filename;
    return $self;
}

sub filename { return shift->{_filename}; }

sub events {
    my ($self) = shift;

    if (defined($self->{_events})) {
        return @{$self->{_events}};
    }
    if (!defined($self->filename())) {
        return undef;
    }
    my @events = $self->_load_events();
    @{$self->{_events}} = @events;
    return @events;
}

sub _load_events {
    my ($self) = shift;
    my $fh = FileHandle->new($self->filename(),"r");
    if (!defined($fh)) {
        # FIXME - use an actual return value
        die "file open: $!";
    }

    my $strp = DateTime::Format::Strptime->new(
        pattern => '%Y-%m-%d %R',
    );

    my @events;
    my $time_prev;
    my $vmidnight_prev;
    while (<$fh>) {
        chomp;

        # Skip comment lines and blank lines
        s/^#.*//;
        s/^\s+//;
        next if m/^$/;

        next if (!m/^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}):\s(.*)/);

        my $time_this = $strp->parse_datetime($1);

        # FIXME - this assumes that the computer creating the gtimelog never
        # moves timezones, but I cannot think of any simple answer ..
        $time_this->set_time_zone('local');

        my $description = $2;

        # FIXME - if !defined time_this ...

        my $vmidnight_this = $self->_dt2vmidnight($time_this);

        # the first entry in the file has no prev time reference
        # or the first entry of the day has a different vmidnight reference
        if (defined($time_prev) and $vmidnight_this == $vmidnight_prev) {
            my $event = Event->new()->set_start($time_prev)->set_finish($time_this)->set_description($description);
            push @event,$event;
        }

        $time_prev = $time_this;
        $vmidnight_prev = $vmidnight_this;
    }
    return @event;
}

sub virtual_midnight {
    my ($self) = @_;

    # TODO - allow actually setting the virtual midnight

    return DateTime::Duration->new(
        hours   => 2,
        minutes => 0,
    );
}

# Given a datetime, calculate what the correct virtual midnight for that
# time is (ie, the first end-of-day after the given datetime)
sub _dt2vmidnight {
    my ($self,$dt) = @_;

    my $vm = $dt->clone();
    $vm->truncate( to=>'day' );
    $vm->add_duration( $self->virtual_midnight() );

    # vm is now right if dt is after 00:00 but before virtual midnight

    if ($dt > $vm) {
        $vm->add( days=>1 );
    }

    return $vm;
}

sub after {
    my ($self,$dt) = @_;

    return grep {$_->start > $dt} $self->events();
}

1;
