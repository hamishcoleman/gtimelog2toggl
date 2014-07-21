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
    return undef if (!defined($projects));

    for my $project (@{$projects}) {
        if ($project->{name} eq $name) {
            return $project->{id};
        }
    }
    return undef;
}

sub hack_event2toggl {
    my ($self,$wid,$event) = @_;

    my ($tag,$project,$desc) = split(/\s*:\s*/,$event->description());

    # Skip things not for us.
    return if ($tag ne 'Toggl');

    my $pid = $self->hack_get_pid_by_name($wid,$project);
    return if (!defined($pid));

    my $fmt = DateTime::Format::Strptime->new(
        pattern => "%FT%H:%M:%SZ",
    );

    my $start = $event->start->clone->set_time_zone('UTC')->set_formatter($fmt);
    my $stop = $event->finish->clone->set_time_zone('UTC')->set_formatter($fmt);

    $self->hack_new_time_entries(
        description  => $desc||'imported',
        pid          => $pid,
        start        => $start.'',
        stop         => $stop.'',
        duration     => $event->minutes()*60,
        created_with => ref($self),
    );
}

sub hack_gtimelog2toggl {
    my $class = shift;
    my %args = (
        @_,
    );

    for my $key (qw(filename after wid api_token)) {
        if (!defined($args{$key})) {
            die "No arg $key";
        }
    }

    my $toggl = $class->new()->set_api_token($args{api_token});

    my $dt = DateTime::Format::ISO8601->parse_datetime($args{after});

    my @events = Gtimelog->new()->set_filename($args{filename})->after($dt);
    for my $event (@events) {
        print "Processing ",$event->as_string(),"\n";
        print Dumper($toggl->hack_event2toggl($args{wid},$event)),"\n";
    }
}


1;


