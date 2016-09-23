package Toggl::Request;
use warnings;
use strict;
#
# Provides a container for the basic toggl request with auth
#

use LWP::UserAgent;
use JSON;
use MIME::Base64;
use DateTime::Format::Strptime;

use DateTime::Format::ISO8601;
use Gtimelog;
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Quotekeys = 0;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my $ua = LWP::UserAgent->new;
    $ua->agent("$class/0.1");

    $self->{_ua} = $ua;

    return $self;
}

sub set_api_token {
    my ($self,$token) = @_;

    #$self->{_ua}->set_basic_credentials($token,'api_token');

    # grr, LWP please be slightly less like a real browser
    my $base64 = encode_base64($token.':api_token');
    $self->{_ua}->default_header( "Authorization" => 'Basic '.$base64 );
    return $self;
}

# FIXME:
# both get and post methods should probably use a common base url and all the
# callers should thus only specify the trailing version and methodname
#
sub get {
    my ($self,$url) = @_;

    my $res = $self->{_ua}->get($url);

    if (!$res->is_success) {
        # TODO - more? or even just die?
        warn $res->status_line;
        return undef;
    }

    if ($res->content_type ne 'application/json') {
        warn "content_type != application/json";
        return undef;
    }

    return decode_json $res->decoded_content;
}

sub post {
    my $self = shift;
    my $url = shift;
    my %args = (
        @_,
    );

    my $args_json = encode_json \%args;

    my $res = $self->{_ua}->post(
        $url,
        'Content-type' => 'application/json',
        'Content' => $args_json,
    );
    
    if (!$res->is_success) {
        # TODO - more? or even just die?
        warn $res->status_line;
        return $res;
    }

    if ($res->content_type ne 'application/json') {
        warn "content_type != application/json";
        return undef;
    }

    return decode_json $res->decoded_content;
}

# should be a subclass..
sub hack_get_workspaces {
    my ($self) = @_;

    my $d = $self->get('https://www.toggl.com/api/v8/workspaces');

    # TODO - parse it ?
    return $d;
}

sub hack_get_workspace_projects {
    my ($self,$wid) = @_;

    if (defined($self->{_wid}{$wid}{pid})) {
        return $self->{_wid}{$wid}{pid};
    }
    my $d = $self->get("https://www.toggl.com/api/v8/workspaces/$wid/projects");

    $self->{_wid}{$wid}{pid} = $d;
    return $d;
}

sub hack_new_time_entries {
    my $self = shift;
    my %args = @_;

    my %d = (
        time_entry => \%args,
    );

    return $self->post('https://www.toggl.com/api/v8/time_entries',%d);
}

sub hack_get_pid_by_name {
    my ($self,$wid,$name) = @_;

    my $projects = $self->hack_get_workspace_projects($wid);
    if (!defined($projects)) {
        warn "No projects!?";
        return undef;
    }

    for my $project (@{$projects}) {
        # TODO
        # - case insensitive compare?
        # - strip wierd chars?
        if ($project->{name} eq $name) {
            return $project->{id};
        }
    }

    warn "Could not find project=$name";
    return undef;
}

sub hack_spliteventdesc {
    my ($self,$event) = @_;

    if (ref($event) ne 'Event') {
        print Dumper(@_);
        die("event not right");
    }

    my ($tag,$project,$desc) = split(/\s*:\s*/,$event->description());
    return ($tag,$project,$desc);
}

sub hack_event2pid {
    my ($self,$wid,$event) = @_;

    if (ref($event) ne 'Event') {
        print Dumper(@_);
        die("event not right");
    }

    my ($tag,$project,$desc) = $self->hack_spliteventdesc($event);

    return $self->hack_get_pid_by_name($wid,$project);
}

sub hack_event2toggl {
    my ($self,$wid,$event) = @_;

    if (ref($event) ne 'Event') {
        print Dumper(@_);
        die("event not right");
    }

    my ($tag,$project,$desc) = $self->hack_spliteventdesc($event);

    # Skip things not for us.
    return if ($tag ne 'Toggl');

    my $pid = $self->hack_event2pid($wid,$event);
    return if (!defined($pid));

    my $fmt = DateTime::Format::Strptime->new(
        pattern => "%FT%H:%M:%SZ",
    );

    my $start = $event->start->clone->set_time_zone('UTC')->set_formatter($fmt);
    my $stop = $event->finish->clone->set_time_zone('UTC')->set_formatter($fmt);

    $self->hack_new_time_entries(
        description  => $desc||'imported', #'No additional description available',
        pid          => $pid,
        start        => $start.'',
        stop         => $stop.'',
        duration     => $event->minutes()*60,
        created_with => ref($self),
    );
}

# Get all time entries.
# From the docs: "If start_date and end_date are not specified, time
#  entries started during the last 9 days are returned. The limit
#  of returned time entries is 1000"
# So this should suffice until I have more than 1000 entries ..
#
sub hack_time_entries {
    my ($self) = @_;
    # TODO - start_date and end_date

    my $d = $self->get("https://www.toggl.com/api/v8/time_entries");

    return $d;
}

# Go through all time entries and return the timestamp of the most recent
# one found.  This allows repeatedly importing the same gtimelog file to simply
# append new data to toggl
sub hack_lasttime {
    my $self = shift;

    my $entries = $self->hack_time_entries();

    my $max_start = '1970-01-01T01:01:00+00:00';
    my $max_start_wid = 1;

    for my $entry (@{$entries}) {
        if ($entry->{start} gt $max_start) {
            $max_start = $entry->{start};
            $max_start_wid = $entry->{wid};
        }
    }

    return ($max_start,$max_start_wid);
}

sub hack_gtimelog2toggl {
    my $class = shift;
    my %args = (
        @_,
    );

    for my $key (qw(filename wid api_token)) {
        if (!defined($args{$key})) {
            die "No arg $key";
        }
    }

    my $toggl = $class->new()->set_api_token($args{api_token});

    # get the last time from the commandline
    if (!defined($args{after})) {
        my ($last,$wid) = $toggl->hack_lasttime();
        $args{after} = $last;
        #if (!defined($args{wid}) { $args{wid} = $wid: }
        print "Automatically setting after = $last\n";
    }

    my $dt = DateTime::Format::ISO8601->parse_datetime($args{after});

    my @events = Gtimelog->new()->set_filename($args{filename})->after($dt);

    # First pass, looking for issues
    for my $event (@events) {
        print "Processing ",$event->as_string(),"\n";
        next if ($event->description =~ m/ \*\*$/); # Skip non work events
        next if ($event->description !~ m/^Toggl:/); # Skip events not beginning with Toggl

        my $pid = $toggl->hack_event2pid($args{wid},$event);
        if (!defined($pid)) {
            die "Could not find project for ",$event->as_string;
        }
    }

    # Second pass, only reached if first pass succeeded, create if we are told to
    if (defined($args{create})) {
        for my $event (@events) {
            print "Processing ",$event->as_string(),"\n";
            print Dumper($toggl->hack_event2toggl($args{wid},$event)),"\n";
        }
    }
}


1;


