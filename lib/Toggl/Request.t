use Test::More;

BEGIN {
    use_ok('Toggl::Request');
}

my $object;
isa_ok(Toggl::Request->new(),'Toggl::Request', 'Create object');

# Dont hardcode passwords.
# Skip things that needs passwords if we dont have one
# This also gives us a way to avoid running things that need net access
# The missing test coverage will only show up in the code coverage reports..
if (!defined($ENV{TOGGL_API_TOKEN})) {
    done_testing();
    exit;
}

isa_ok($object->set_api_token($ENV{TOGGL_API_TOKEN}),'Toggl::Request','Set API key');

done_testing();
