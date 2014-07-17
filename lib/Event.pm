package Event;
#
# A generic timesheet entry
#
# Reused by other parts to 
#

use HC::Strptime;

# Use one global instance for all cases
my $_parser = HC::Strptime->format();

sub new {
    my ($class) = shift;
    my $self = {};
    bless $self, $class;

    return $self;
}

sub set_start {
    my ($self) = shift;
    my ($dt) = shift;

    # assume we are given the dt object, so force it to match our expectations
    $dt->set_formatter($_parser);
    $self->{_start} = $dt;
    return $self;
}

sub set_minutes {
    my ($self) = shift;
    my ($minutes) = shift;

    $self->{_minutes} = $minutes;
    return $self;
}

sub set_description {
    my ($self) = shift;
    my ($description) = shift;

    $self->{_description} = $description;
    return $self;
}

sub start { return shift->{_start}; }
sub minutes { return shift->{_minutes}; }
sub description { return shift->{_description}; }

sub as_string {
    my ($self) = shift;

    if (!(defined($self->start()) and defined($self->minutes()))) {
        return undef;
    }

    return sprintf("%s, %im, %s",
        $self->start(),
        $self->minutes(),
        $self->description()||'',
    );
}

1;
