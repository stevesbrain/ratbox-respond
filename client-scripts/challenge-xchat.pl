#!/usr/bin/perl -w
#
# challenge-xchat.pl
# Copyright (C) 2006 Lee Hardy <lee -at- leeh.co.uk>
# Copyright (C) 2006 ircd-ratbox development team
# 
# $Id$

package IRC::XChat::ratboxchallenge;

use IPC::Open2;
use FileHandle;

#########################
# Configuration Variables
#########################

# respond_path: The absolute path to the "ratbox-respond" program.
my $respond_path = "/home/leeh/respond/respond/ratbox-respond";

# private key path: The absolute path to your private key.
my $private_key_path = "/home/leeh/respond/private.key";

###################
# END CONFIGURATION
###################

my $script_name = "ratbox-challenge";
my $script_version = "1.0";
my $script_descr = "CHALLENGE opering script for use with ircd-ratbox";

Xchat::register($script_name, $script_version, $script_descr, "");
Xchat::print("Loading $script_name $script_version - $script_descr");

my $pkg == __PACKAGE__;

my $challenge;
my $keyphrase = "";
my $doing_challenge = 0;

Xchat::hook_server("740", "${pkg}::handle_rpl_rsachallenge2");
Xchat::hook_server("741", "${pkg}::handle_rpl_endofrsachallenge2");

my $challenge_options = {
	help_text => "Usage: /challenge <opername> [keyphrase]"
};

Xchat::hook_command("CHALLENGE", "${pkg}::handle_challenge", $challenge_options);

sub handle_challenge
{
	# generated by this function, avoid recursion
	return Xchat::EAT_NONE
		if($doing_challenge);

	my $opername = $_[0][1];

	if(!$opername)
	{
		Xchat::print("Usage: /challenge <opername> [keyphrase]");
		return Xchat::EAT_ALL;
	}

	$challenge = "";

	$keyphrase = $_[0][2]
		if($_[0][2]);

	# hack -- this stops us recursing.
	$doing_challenge = 1;
	Xchat::command("CHALLENGE $opername\n");
	$doing_challenge = 0;

	return Xchat::EAT_ALL;
}

sub handle_rpl_rsachallenge2
{
	my $reply = $_[0][3];

	# remove the initial ':'
	$reply =~ s/^://;

	$challenge .= $reply;
	return Xchat::EAT_ALL;
}

sub handle_rpl_endofrsachallenge2
{
	Xchat::print("ratbox-challenge: Received challenge, generating response..");

	unless(open2(*Reader, *Writer, "$respond_path $private_key_path"))
	{
		Xchat::print("ratbox-challenge: Unable to execute respond from $respond_path");
		return Xchat::EAT_ALL;
	}

	print Writer "$keyphrase\n";
	print Writer "$challenge\n";

	# done for safety.. this may be irrelevant in perl!
	$keyphrase =~ s/./0/g;
	$keyphrase = "";

	$challenge =~ s/./0/g;
	$challenge = "";

	my $output = scalar <Reader>;
	chomp($output);

	close(RESPOND);

	if($output =~ /^Error:/)
	{
		Xchat::print("ratbox-challenge: $output");
		return Xchat::EAT_ALL;
	}

	Xchat::print("ratbox-challenge: Received response, opering..");

	$doing_challenge=1;
	Xchat::command("CHALLENGE +$output");
	$doing_challenge=0;

	return Xchat::EAT_ALL;
}

1;
