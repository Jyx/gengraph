#!/usr/bin/perl
################################################################################
#  Author: Joakim Bech (joakim.bech@gmail.com)                                 #
################################################################################
use strict;
use warnings;
use File::Find;

################################################################################
#  Global scalars, arrays and hashes                                           #
################################################################################
my $debug = 0;
my $level = 0;
my $graphvis = "";
my $dotfile = "mygraph";
my $dotextension = "dot";
my $picture_ext = "jpg";
my $root_folder = ".";

my %existing_files;

################################################################################
#  Sub routines                                                                #
################################################################################
sub check_input {
	foreach my $arg (@ARGV) {
		if ($arg =~ m/^-d$/) {
			$debug = 1;
		} elsif ($arg =~ m/^-\d$/) {
			$arg =~ s/-//;
			$level = $arg;
		} elsif ($arg =~ m/^-dot$/) {
			$graphvis = "dot";
		} elsif ($arg =~ m/^-neato$/) {
			$graphvis = "neato";
		} elsif ($arg =~ m/^-twopi$/) {
			$graphvis = "twopi";
		} elsif ($arg =~ m/^-png$/) {
			$picture_ext = "png";
		} else {
			$root_folder = $arg;
		}
	}

	print "Parameters from \@ARGV\n" if $debug;
	print "=====================\n" if $debug;
	map { print "$_\n" } @ARGV if $debug;
	print "\n" if $debug;
}

sub show_globals {
	print "Global variables\n";
	print "================\n";
	print "debug: $debug\n";
	print "level: $level\n";
	print "graphvis: $graphvis\n";
	print "dotfile: $dotfile\n";
	print "dotextension: $dotextension\n";
	print "picture_ext: $picture_ext\n";
	print "root_folder: $root_folder\n";
	print "\n";
}

sub make_graph {
	print "Generating $graphvis graph\n";
	system("$graphvis -T$picture_ext $dotfile\.$dotextension -o $dotfile\_$graphvis\.$picture_ext");
}

sub save_files {
	print "File: $_\n" if $debug;
	print "Dir:  $File::Find::dir\n\n" if $debug;
	$existing_files{$_} = $File::Find::dir;
}

sub generate_file_list {
	chdir($_[0]);
	find(\&save_files, ".");
	&print_file_list if $debug;
}

sub print_file_list {
	print "File list\n=========\n";
	foreach my $key (sort keys %existing_files) {
		print "$key $existing_files{$key}\n";
	}
}

################################################################################
#  Main program                                                                #
################################################################################
print "gengraph - A script for making dependency graph for source code\n\n";
&check_input;
&show_globals if $debug;
&generate_file_list($root_folder);

&make_graph if $graphvis;
