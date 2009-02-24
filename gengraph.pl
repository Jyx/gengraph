#!/usr/bin/perl
################################################################################
#  Author: Joakim Bech (joakim.bech@gmail.com)                                 #
################################################################################
use strict;
use warnings;
use Cwd;
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
my %existing_folders;

################################################################################
#  Sub routines                                                                #
################################################################################
sub parse_inparameters {
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
	my $filename = "$dotfile\.$dotextension";
	if (-e $filename) {
		print "Generating $graphvis graph\n";
		system("$graphvis -T$picture_ext $filename -o $dotfile\_$graphvis\.$picture_ext");
	} else {
		print "Couldn't open file $filename in folder " . getcwd . "\n";
	}
}

sub save_files {
	if ($_ =~ m/\.[ch]$/) {
		my $file = $_;
		my $dir = $File::Find::dir;

		print "File: $file\n" if $debug;
		print "Dir:  $dir\n\n" if $debug;

		# Store the file name
		$existing_files{$file} = $dir;

		my @splitted_folder = split(/\//, $dir);
		# This is tricky, we have some special cases here. First we need to take
		# care of when the number of subfolder is greater than the provided
		# level variable. All those files in sub directories further down we
		# treat as a if they exist in the same sub folder.
		#
		# The next case is when files exist between 1 and the variable level
		# number of sub folders.
		#
		# The last case, the else, is when files are located in the root folder.
		if (scalar(@splitted_folder) > $level) {
			my $dir_string;
			for my $i (0 .. $level) {
				$dir_string = $dir_string . "$splitted_folder[$i]";
				$dir_string = $dir_string . "\/" if ($i < $level);
				#print "dir_string: $dir_string\n" if $debug;
			}
			print "Greater than level\n";
			push(@{$existing_folders{$dir}}, $file);
		} elsif (scalar(@splitted_folder) > 1 &&
				 scalar(@splitted_folder) <= $level) {

			print "2 to level\n";
		} else {
			print "Zero\n";
		}
	}
}

sub generate_file_lists {
	my $root = getcwd;
	if (-d $_[0]) {
		chdir($_[0]);
		find(\&save_files, ".");
		&print_file_list if $debug;
		&print_folder_list if $debug;
		chdir($root);
	} else {
		print "Unknown root folder: $_[0]\n";
	}
}

sub print_file_list {
	print "\nFile list\n=========\n";
	foreach my $key (sort {$existing_files{$a} cmp $existing_files{$b}}
					 keys %existing_files) {
		print "  $key $existing_files{$key}\n";
	}
}

sub print_folder_list {
	print "\nFolder list (" . keys (%existing_folders) . ")\n";
	print "===================\n";
	foreach my $key (keys %existing_folders) {
		print "$key $existing_folders{$key}\n";
		foreach my $file (@{$existing_folders{$key}}) {
			print "  $file\n";
		}
	}
}

sub is_file_known {
	my $file_to_check = $_[0];
	if ($existing_files{$file_to_check}) {
		print "File exist on path $existing_files{$file_to_check}\n" if $debug;
		return 1;
	}
	return 0;
}

sub make_subgraphs {
	foreach my $key (sort {$existing_files{$a} cmp $existing_files{$b}}
					 keys %existing_files) {
		my @splitted_folder = split(/\//, $existing_files{$key});
		#map { print "$_\n" } @splitted_folder if $debug;
		#print "Size: " .scalar(@splitted_folder) . "\n";
	}
}

################################################################################
#  Main program                                                                #
################################################################################
print "gengraph - A script for making dependency graph for source code\n\n";
&parse_inparameters;
&show_globals if $debug;
&generate_file_lists($root_folder);
#&make_subgraphs;

&make_graph if $graphvis;
