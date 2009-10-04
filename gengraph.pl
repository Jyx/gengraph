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
my $graphviz = "";
my $dotfile = "mygraph";
my $dotextension = "dot";
my $picture_ext = "jpg";
my $script_folder = getcwd;
my $root_folder = $script_folder;

my $DOT_FILEHANDLE;

# This hash contains all files (keys) on the filesystem and stores their path,
# i.e. the path as the data.
my %file_path_hash;

# This hash contains all files (keys) and their path up to a certain $level.
my %file_levelpath_hash;

# Hash for "unknown" files, i.e files that isn't in the tree provided to the
# script.
my %unknown_file_list_hash;

# Used for handing indent for the written graph.
my $current_indents;

# Used for making uniq id's to subgraphs.
my $uniq_id = 0;

my @temporary_file_storage;

################################################################################
#  Printing sub routines                                                       #
################################################################################
sub print_help {
	print "Usage: ./genperl [-d | -h | -png | -1 | -dot | -neato | -twopi]";
	print " path\n";
	print "                 -d      For debug information\n";
	print "                 -h      This help\n";
	print "                 -png    Generates a picture in png format\n";
	print "                 -1      Folder level, i.e. 1 to any number is";
	print " possible\n";
	print "                 -dot    Generates a dot graph\n";
	print "                 -neato  Generates a neato graph\n";
	print "                 -twopi  Generates a twopi graph\n";
}

sub print_file_list {
	print "\nFile list\n=========\n";
	foreach my $key (sort {$file_path_hash{$a} cmp $file_path_hash{$b}}
					 keys %file_path_hash) {
		print "  $key $file_path_hash{$key}\n";
	}
}

sub show_globals {
	print "Global variables\n";
	print "================\n";
	print "debug: $debug\n";
	print "level: $level\n";
	print "graphviz: $graphviz\n";
	print "dotfile: $dotfile\n";
	print "dotextension: $dotextension\n";
	print "picture_ext: $picture_ext\n";
	print "root_folder: $root_folder\n";
	print "script_folder: $script_folder\n";
	print "\n";
}

################################################################################
#  Utility sub routines                                                        #
################################################################################
sub write_to_graph {
	my $string_to_print = $_[0];
	print $string_to_print if $debug;
	print $DOT_FILEHANDLE $string_to_print;
}

sub get_name_of_graph {
	my @name_of_graph = split(/\//, $root_folder);
	return $name_of_graph[-1];
}

# Function removes the ending slash of a string give as inparameter.
sub remove_end_slash {
	my $path = $_[0];
	$path =~ s/[\\\/]$//;
	return $path;
}

# Function that removes the preceding dot.
sub remove_start_dot {
	my $path = $_[0];
	$path =~ s/^\.//;
	return $path;
}

# File that is used to check whether a file is known.
sub is_file_known {
	my $file_to_check = $_[0];
	if ($file_path_hash{$file_to_check}) {
		print "File exist on path $file_path_hash{$file_to_check}\n" if $debug;
		return 1;
	}
	return 0;
}

sub unknown_file_already_stored {
	#my $filename = $_[0];
	if ($unknown_file_list_hash{$_[0]}) {
		return 1;
	}
	return 0;
}

# Close the graph by writing an ending } character
sub close_graph {
	write_to_graph("}\n");
}

################################################################################
#  Parsing sub routines                                                        #
################################################################################
sub parse_inparameters {
	foreach my $arg (@ARGV) {
		if ($arg =~ m/^-d$/) {
			$debug = 1;
		} elsif ($arg =~ m/^-\d$/) {
			$arg =~ s/-//;
			$level = $arg;
		} elsif ($arg =~ m/^-dot$/) {
			$graphviz = "dot";
		} elsif ($arg =~ m/^-neato$/) {
			$graphviz = "neato";
		} elsif ($arg =~ m/^-twopi$/) {
			$graphviz = "twopi";
		} elsif ($arg =~ m/^-png$/) {
			$picture_ext = "png";
		} elsif ($arg =~ m/^-h$/) {
            &print_help;
			exit;
		} else {
			if (-d $arg) {
				chdir ($arg);
				$root_folder = getcwd;
			} else {
				# Error, fail nicely!
				print "$arg not valid path!\n";
				exit;
			}
		}
	}

	print "Parameters from \@ARGV\n" if $debug;
	print "=====================\n" if $debug;
	map { print "$_\n" } @ARGV if $debug;
	print "\n" if $debug;
}

sub make_graph {
	chdir($script_folder);
	my $filename = "$dotfile\.$dotextension";
	if (-e $filename) {
		print "Generating $graphviz graph ...\n";
		system("$graphviz -T$picture_ext $filename -o $dotfile\_$graphviz\.$picture_ext");
	} else {
		print "Couldn't open file $filename in folder " . getcwd . "\n";
	}
}

sub get_remaining_files {
	# We are only interested in c-, and h-files for the moment.
	if ($_ =~ m/\.[ch]$/) {
		write_to_graph("$current_indents    \"$_\"\n");
		$file_path_hash{$_} = getcwd;
	}
}

# This is a recursive function that will traverse all folders from the base of
# the provided root folder. When $level variable have decreaed to zero, then
# then File::Find function will look after filenames only in the rest of the
# subdirectories.
sub traversefolders {
	my $folder = $_[0];
	my $level = $_[1];
	my $offset = $_[2];
	my $offset_string = (" " x $offset);

	my $inpath = getcwd;
	chdir($folder);

	# Write header and subgraph headers
	if ($offset == 0) {
		my $name_of_graph = &get_name_of_graph;
		&write_to_graph("digraph ");
		&write_to_graph("$name_of_graph\_\_$level {\n");
		&write_to_graph("    graph [fontsize=24];\n");
		&write_to_graph("    edge [color = blue penwidth=0.4];\n");
		&write_to_graph("    rankdir = \"LR\";\n");
		&write_to_graph("    ranksep = 1.5;\n");
		&write_to_graph("    nodesep = .25;\n");

		# Twopi specific settings.
		if ($graphviz eq "dot") {
		}

		# Neato specific settings.
		if ($graphviz eq "neato") {
			&write_to_graph("    edge [len=2.5];\n");
		}

		# Twopi specific settings.
		if ($graphviz eq "twopi") {
		}
	} elsif ($offset > 0) {
		&write_to_graph("\n" . $offset_string . "subgraph \"cluster");
		&write_to_graph("$folder\_\_$uniq_id\" {\n");
		&write_to_graph($offset_string . "    label = \"$folder\";\n");
		&write_to_graph($offset_string . "    fontname = \"arial\";\n");
		$uniq_id++;

		# Deal with the colors of the subgraph.
		my $bgcolor = "lemonchiffon1";
		if ($level % 2) {
			$bgcolor = "khaki";
		}
		&write_to_graph($offset_string . "    bgcolor = \"$bgcolor\";\n");
	}

	opendir(DIR, ".");
	my @files = readdir(DIR);
	closedir(DIR);

	foreach my $file (@files) {
		# We don't want to traverse . and ..
		next if ($file eq "." or $file eq "..");

		# Save the current indentation offset for the find function.
		$current_indents = $offset_string;

		if ($level == 0 and -d $file) {
			find(\&get_remaining_files, $file);
			next;
		}

		if (-f $file) {
			# We are only interested in c-, and h-files for the moment.
			if ($file =~ m/\.[ch]$/) {
				&write_to_graph("$offset_string    \"$file\"\n");

				# Here we store the file found and its actual (full) path.
				$file_path_hash{$file} = getcwd;
			}
			next;
		}
		
		&traversefolders($file, $level - 1, $offset + 4);
	}
	chdir($inpath);

	&write_to_graph("$offset_string}\n") if ($offset > 0);
}

sub open_dot_file {
	open $_[0], ">$script_folder/$_[1]", or die $!;
	print "Opened file: $_[1]\n" if $debug;
}

sub close_dot_file {
	close $_[0];
	print "Closed file: $_[0]\n" if $debug;
}

# This function parses a single file searching for the files which it includes.
# It writes a connection between the file itself and the files it includes.
sub parse_individual_file {
	my $parsed_filename = $_;
	my $file = getcwd . "/" . $_;
	if (-e $file) {
		#print "Parse ... $file\n" if $debug;
		open FILE, "<$file" or die $!;
		my @include_files = grep /#include/, <FILE>;

		# Loop through all the lines containing the text #include.
		foreach my $include_line (@include_files) {
			chomp($include_line);

			if ($include_line =~ m/^ *#include *[<"](.*)[">].*$/) {
				# Check if the file is already stored in the hash, i.e. known
				# since the traverse stage done earlier.
				if (&is_file_known($1) or &unknown_file_already_stored($1)) {
					push(@temporary_file_storage,
						 "    \"$parsed_filename\"-> \"$1\"\n");
				} else {
					push(@temporary_file_storage,
						 "    \"$1\" [color = red];\n");

					push(@temporary_file_storage,
						 "    \"$parsed_filename\"-> \"$1\"\n"); 

					# Add "unknown" file to the hash.
					$unknown_file_list_hash{$1} = 1;
				}
			}
		}
		close FILE;
	}
}

sub parse_files_in_hash {
	print $DOT_FILEHANDLE "\n";
	find(\&parse_individual_file, $root_folder);
	map { &write_to_graph("$_") } sort @temporary_file_storage;
}

################################################################################
#  Main program                                                                #
################################################################################
print "gengraph - A script for making dependency graph for source code\n\n";
&parse_inparameters;
&show_globals if $debug;
&open_dot_file($DOT_FILEHANDLE, "$dotfile\.$dotextension");
&traversefolders($root_folder, $level, 0);
&print_file_list if $debug;

&parse_files_in_hash;

&close_graph($DOT_FILEHANDLE);

&close_dot_file($DOT_FILEHANDLE);

system("cat $script_folder/$dotfile\.$dotextension") if $debug;

&make_graph if $graphviz;
