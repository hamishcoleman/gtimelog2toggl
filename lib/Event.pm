package Event;
use warnings;
use strict;
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

# assume we are given the dt object, so force it to match our expectations
sub _fixup_datetime {
    my ($self) = shift;
    my ($dt) = shift;

    # We could have a global timezone setting here

    $dt->set_formatter($_parser);
}

sub set_start {
    my ($self) = shift;
    my ($dt) = shift;

    $self->_fixup_datetime($dt);
    $self->{_start} = $dt;
    return $self;
}

sub set_finish {
    my ($self) = shift;
    my ($dt) = shift;

    $self->_fixup_datetime($dt);
    $self->{_finish} = $dt;
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

# Currently, we only handle minutes missing, we could also handle having any
# one out of (start,finish,minutes) be missing..
#

sub minutes {
    my ($self) = shift;
    if (defined($self->{_minutes})) {
        return $self->{_minutes};
    }
    if (defined($self->start()) and defined($self->finish())) {
        return ($self->finish()-$self->start())->in_units('minutes');
    }
    return undef;
}

sub start { return shift->{_start}; }
sub finish { return shift->{_finish}; }
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
