#! /usr/bin/perl

# Copyright (c) 2018, AT&T Intellectual Property. All rights reserved.
#
# Validate and list user-defined applications.
#

use strict;
use warnings;

use lib "/opt/vyatta/share/perl5";

use Getopt::Long;
use Vyatta::Dataplane;
use Vyatta::Config;

my $CMD_PREFIX = "service application";

my $fabric;
my ( $dp_ids, $dp_conns, $local_controller ) =
  Vyatta::Dataplane::setup_fabric_conns($fabric);

my ( $opt_action, $opt_value );

# Action dispatch table
my %actions = (
    "list"      => \&list_user_apps,
    "validate"  => \&validate_user_app,
);

# Options
#
# action = validate [default] | list
# value = name to validate
#
GetOptions(
    "action=s" => \$opt_action,
    "value=s"  => \$opt_value,
);

# Default action
$opt_action //= "validate";

my $config = new Vyatta::Config;

die "No user-defined applications are configured\n"
    if (! $config->exists($CMD_PREFIX) );

# Dispatch action
#
my $rv = ( $actions{$opt_action} )->();

# Close down ZMQ sockets. This is needed or sometimes a hang
# can occur due to timing issues with libzmq - see VRVDR-17233 .
#
Vyatta::Dataplane::close_fabric_conns( $dp_ids, $dp_conns );

exit $rv;

# List all application name and application protocol nodes under $CMD_PREFIX.
# These all have application IDs, so any of them can be used in FW/PBR/QoS.

sub list_user_apps {
    my $rv = 1;

    my @rules = $config->listNodes("$CMD_PREFIX rule");
    foreach my $rule (@rules) {
        my $name = $config->returnValue("$CMD_PREFIX rule $rule then name");
        if (defined($name)) {
            print "$name\n";
            $rv = 0;
        }

        my $proto = $config->returnValue("$CMD_PREFIX rule $rule then protocol");
        if (defined($proto)) {
            print "$proto\n";
            $rv = 0;
        }
    }

    return $rv;
}

sub validate_user_app {
    die "Missing --value\n"
        if (not defined $opt_value);

    my @rules = $config->listNodes("$CMD_PREFIX rule");
    foreach my $rule (@rules) {
        my $node = $config->exists("$CMD_PREFIX rule ".$rule." then name $opt_value");
        return 0 if defined($node);
        $node = $config->exists("$CMD_PREFIX rule ".$rule." then protocol $opt_value");
        return 0 if defined($node);
    }

    # Not defined
    return 1;
}
