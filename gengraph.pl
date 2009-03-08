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
my $script_folder = getcwd;
my $root_folder = $script_folder;
my $folder_view = 0;

my $DOT_FILEHANDLE;

my %file_list_hash;
my %existing_folders;
my %folder_dependencies;

# Used for handing indent for the written graph.
my $current_indents;

################################################################################
#  Printing sub routines                                                       #
################################################################################
sub print_help {
	print "Usage: ./genperl [-d | -f | -h | -png | -1 | -dot | -neato | -twopi]";
	print " path\n";
	print "                 -d      For debug information\n";
	print "                 -f      For folder dependencies\n";
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
	foreach my $key (sort {$file_list_hash{$a} cmp $file_list_hash{$b}}
					 keys %file_list_hash) {
		print "  $key $file_list_hash{$key}\n";
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

sub print_folder_dependencies {
	my $file = $_[0];
	foreach my $key (keys %folder_dependencies) {
		my %hash   = map { $_, 1 } @{$folder_dependencies{$key}};
		my @unique = keys %hash;
		# Replace . with Root, this should be done in a nicer way.
		$key =~ s/^.$/Root/g;
		$key =~ s/\.\///g;
		foreach my $folder (@unique) {
			print $file "  \"$key\" -> \"$folder\"\n";
		}
	}
}

sub print_graph_header {
	my $file = $_[0];
	print "\nGraph header\n============\n" if $debug;
	print $file "digraph G {\n";
	print "digraph G {\n" if $debug;
}

sub print_graph_footer {
	my $file = $_[0];
	print "\nGraph footer\n============\n" if $debug;
	print $file "}\n";
	print "}\n" if $debug;
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
	print "script_folder: $script_folder\n";
	print "folder_view: $folder_view\n";
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
	if ($file_list_hash{$file_to_check}) {
		print "File exist on path $file_list_hash{$file_to_check}\n" if $debug;
		return 1;
	}
	return 0;
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
			$graphvis = "dot";
		} elsif ($arg =~ m/^-neato$/) {
			$graphvis = "neato";
		} elsif ($arg =~ m/^-twopi$/) {
			$graphvis = "twopi";
		} elsif ($arg =~ m/^-png$/) {
			$picture_ext = "png";
		} elsif ($arg =~ m/^-f$/) {
			$folder_view = 1;
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
	my $filename = "$dotfile\.$dotextension";
	if (-e $filename) {
		print "Generating $graphvis graph ...\n";
		system("$graphvis -T$picture_ext $filename -o $dotfile\_$graphvis\.$picture_ext");
	} else {
		print "Couldn't open file $filename in folder " . getcwd . "\n";
	}
}

sub save_files {
	if ($_ =~ m/\.[ch]$/) {
		my $file = $_;
		my $dir = $File::Find::dir;
		$dir =~ s/^.[\/]*//;

		print "File: $file\n" if $debug;
		print "Dir:  $dir\n" if $debug;
		print "Path: $File::Find::name\n";

		# Store the file name
		$file_list_hash{$file} = $dir;

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
		my $size_of_path = scalar(@splitted_folder);
		my $dir_string = "";

		if ($size_of_path > $level) {
			for my $i (0 .. $level) {
				$dir_string = $dir_string . "$splitted_folder[$i]";
				$dir_string = $dir_string . "\/" if ($i < $level);
				print "dir_string: $dir_string\n" if $debug;
			}
			push(@{$existing_folders{$dir_string}}, $file);
		} elsif ($size_of_path > 1 && $size_of_path <= $level) {
			for my $i (0 .. $size_of_path) {
				$dir_string = $dir_string . "$splitted_folder[$i]";
				$dir_string = $dir_string . "\/" if ($i < $size_of_path);
			}
			push(@{$existing_folders{$dir_string}}, $file);
		} else {
			push(@{$existing_folders{$splitted_folder[0]}}, $file);
		}
	}
	print "\n\n" if $debug;
}

sub get_remaining_files {
	if ($_ =~ m/\.[ch]$/) {
		write_to_graph("$current_indents    \"$_\"\n");
		$file_list_hash{$_} = getcwd;
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

	opendir(DIR, ".");
	my @files = readdir(DIR);
	closedir(DIR);

	# Write header and subgraph headers
	if ($offset == 0) {
		my $name_of_graph = &get_name_of_graph;
		&write_to_graph("digraph ");
		&write_to_graph("$name_of_graph\_\_$level {\n");
	} elsif ($offset > 0) {
		&write_to_graph("\n" . $offset_string . "subgraph \"cluster");
		&write_to_graph("$folder\_\_$level\" {\n");
		&write_to_graph($offset_string . "    label = \"$folder\"\n");
	}

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
				$file_list_hash{$file} = getcwd;
			}
			next;
		}
		
		&traversefolders($file, $level - 1, $offset + 4);
	}
	chdir($inpath);
	&write_to_graph("$offset_string}\n");
}

sub make_subgraphs {
	my $file = $_[0];
	print "\nMake subgraphs\n==============\n" if $debug;
	foreach my $key (keys %existing_folders) {
		if ($key eq ".") {
			print $file "  subgraph \"clusterRoot\" {\n";
			print $file "    bgcolor=grey\n";
			print $file "    label = \"Root\"\n";
		} else {
			my $modified_header = $key;
			$modified_header =~ s/\.\///;
			print $file "  subgraph \"cluster$modified_header\" {\n";
			print $file "    bgcolor=grey\n";
			print $file "    label = \"$modified_header\"\n";
		}
		foreach my $filename (@{$existing_folders{$key}}) {
			print "  $filename\n" if $debug;
			print $file "    \"$filename\"\n";
		}
		print $file "  }\n\n";
	}
}

sub open_dot_file {
	open $_[0], ">$script_folder/$_[1]", or die $!;
	print "Opened file: $_[1]\n" if $debug;
}

sub close_dot_file {
	close $_[0];
	print "Closed file: $_[0]\n" if $debug;
}

sub parse_file {
	my $parsed_filename = $_;
	my $file = getcwd . "/" . $_;
	if (-e $file) {
		#print "Parse ... $file\n" if $debug;
		open FILE, "<$file" or die $!;
		my @include_files = grep /#include/, <FILE>;
		foreach my $include_line (@include_files) {
			chomp($include_line);

			if ($include_line =~ m/^ *#include *[<"](.*)[">].*$/) {
				if (&is_file_known($1)) {
					print "  \"$parsed_filename\"-> \"$1\"\n" if $debug;
					print $DOT_FILEHANDLE "  \"$parsed_filename\"-> \"$1\"\n";
				} else {
					print "  \"$1\" [color = red];\n" if $debug;
					print "  \"$parsed_filename\"-> \"$1\"\n" if $debug;
					print $DOT_FILEHANDLE "  \"$1\" [color = red];\n";
					print $DOT_FILEHANDLE "  \"$parsed_filename\"-> \"$1\"\n";
				}
			}
		}
		close FILE;
	}
}

sub parse_files_in_hash {
	find(\&parse_file, $root_folder);
}

sub make_folder_dependencies {
	print "\nFolder dependencies (" . keys (%existing_folders) . ")\n" if $debug;
	print "===================\n" if $debug;
	my $root = getcwd;
	chdir($root_folder);
	foreach my $key (keys %existing_folders) {
		print "$key $existing_folders{$key}\n" if $debug;
		foreach my $file (@{$existing_folders{$key}}) {
			open FILE, "<$file_list_hash{$file}/$file" or die $!;
			my @include_files = grep /#include/, <FILE>;
			foreach my $include_line (@include_files) {
				chomp($include_line);

				if ($include_line =~ m/^ *#include *[<"](.*)[">].*$/) {
					# print "  $file includes $1\n";
					$key =~ s/\.\///g;
					if (is_file_known($1)) {
						my @splitted_folder = split(/\//, $file_list_hash{$1});
						if (scalar(@splitted_folder) >= 2) {
							print "  adding $key -> $splitted_folder[1]\n"
								if $debug;
							push(@{$folder_dependencies{$key}},
									$splitted_folder[1]);
						} else {
							print "  adding $key -> Root\n"
								if $debug;
							push(@{$folder_dependencies{$key}}, "Root");
						}
					} else {
							print "  *adding $key -> Unknown\n"
								if $debug;
							push(@{$folder_dependencies{$key}}, "Unknown");
					}
				}
			}
			close FILE;
		}
	}
	chdir($root);
}

################################################################################
#  Main program                                                                #
################################################################################
print "gengraph - A script for making dependency graph for source code\n\n";
&parse_inparameters;
&show_globals if $debug;
&open_dot_file($DOT_FILEHANDLE, "$dotfile\.$dotextension");
&traversefolders($root_folder, $level, 0);
&close_dot_file($DOT_FILEHANDLE); # Remove later on...
&print_file_list;
exit;

&print_graph_header($DOT_FILEHANDLE);
if ($folder_view) {
	&make_folder_dependencies;
	&print_folder_dependencies($DOT_FILEHANDLE);
} else {
	&make_subgraphs($DOT_FILEHANDLE);
	&parse_files_in_hash;
}
&print_graph_footer($DOT_FILEHANDLE);

&close_dot_file($DOT_FILEHANDLE);

&make_graph if $graphvis;
