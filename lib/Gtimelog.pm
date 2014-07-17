package Gtimelog;
#
# Routines for opening and using a gtimelog file
#

use FileHandle;
use DateTime::Format::Strptime;
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

        if (!defined($time_prev)) {
            # the first entry in the file has no reference
            $time_prev = $time_this;
            next;
        }

        # FIXME - if virtual_midnight is between prev and this, then we also
        # need to reset time_prev and skip this line

        my $minutes = ($time_this-$time_prev)->in_units('minutes');

        my $event = Event->new()->set_start($time_prev)->set_minutes($minutes)->set_description($description);
        push @event,$event;
        $time_prev = $time_this;
    }
    return @event;
}

1;
