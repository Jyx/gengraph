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

my $temporary_working_dir = "";

# This hash contains all files (keys) on the filesystem and stores their path,
# i.e. the path as the data.
my %file_path_hash;
my %file_path_true_hash;

my %folder_folder_hash;

my $current_working_dir_in_traverse_tree = $root_folder;

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

sub print_file_list {
	print "\nFile list (file_path_hash)\n==========================\n";
	foreach my $key (sort {$file_path_hash{$a} cmp $file_path_hash{$b}}
					 sort keys %file_path_hash) {
		my $offset_string = (" " x (20 - length($key)));
		print "  $key $offset_string $file_path_hash{$key}\n";
	}

	print "\n true path's\n -----------\n";
	foreach my $key (sort {$file_path_true_hash{$a} cmp $file_path_true_hash{$b}}
					 sort keys %file_path_true_hash) {
		my $offset_string = (" " x (20 - length($key)));
		print "  $key $offset_string $file_path_true_hash{$key}\n";
	}

	print "\n folder to folder hash's\n -----------------------\n";
	foreach my $key (sort {$folder_folder_hash{$a} cmp $folder_folder_hash{$b}}
						 sort keys %folder_folder_hash) {
		if (defined $folder_folder_hash{$key}) {
			my $offset_string = (" " x (20 - length($key)));
			print "  $key $offset_string $folder_folder_hash{$key}\n";
		}
	}
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

sub find_files {
	# We are only interested in c-, and h-files for the moment.
	if ($_ =~ m/\.[ch]$/) {
		my @stripped_path;
		my @sw_dir = split(/\//, $temporary_working_dir);

		for (my $i = 0; $i < $level; $i++) {
			# This is a trick to cut away the beginning of the path and only leave $level folders.
			unshift(@stripped_path, pop(@sw_dir));
		}

		$file_path_hash{$_} = join("/", @stripped_path);
		$file_path_true_hash{$_} = getcwd;
	}
}

# This function creates two hashes of all files deeper down in folder structure than $level.
# One hash have the true path for all files.
# The other hash have the condensed path for all files.
sub traverse_tree {
	my $current_level = $_[0];
	my $working_folder = $_[1];

	chdir($working_folder);

	opendir(DIR, ".");
	my @files = readdir(DIR);
	closedir(DIR);

	foreach my $file (@files) {
		# Ignore . and ..
		next if ($file eq "." or $file eq "..");

		my $file_fullpath = $working_folder . "/" . $file;

		if (-d $file_fullpath and ($current_level < $level)) {
			&traverse_tree($current_level + 1, $file_fullpath);
			# Don't continue as long as level is below expected level!
			next;
		}

		if ($current_level == $level) {
			$temporary_working_dir = $working_folder;
			find(\&find_files, $file_fullpath);
		}

	}
}

sub parse_files {
	foreach my $key (sort {$file_path_true_hash{$a} cmp $file_path_true_hash{$b}}
					 sort keys %file_path_true_hash) {
		open FILE, "<$file_path_true_hash{$key}/$key" or die $!;
		my @include_files = grep /#include/, <FILE>;
		close FILE;

		foreach my $include_line (@include_files) {
			if ($include_line =~ m/^ *#include *[<"](.*)[">].*$/) {
				my $folder_value_from_include_file = $file_path_hash{$1};
				my $folder_key_from_origin_file = $file_path_hash{$key};

				# Don't store anything if it's an unknown file.
				if (defined $folder_value_from_include_file) {
					# And don't store links to it self.
					next if ($folder_key_from_origin_file eq $folder_value_from_include_file);
					$folder_folder_hash{$folder_key_from_origin_file} = $folder_value_from_include_file;
				}
			}
		}
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

sub write_to_graph {
	my $string_to_print = $_[0];
	print $string_to_print if $debug;
	print $DOT_FILEHANDLE $string_to_print;
}

sub create_graph {
		&write_to_graph("digraph ");
		&write_to_graph(" depgraph {\n");
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

		foreach my $key (sort {$folder_folder_hash{$a} cmp $folder_folder_hash{$b}}
						 sort keys %folder_folder_hash) {
			&write_to_graph("    \"$key\" -> \"$folder_folder_hash{$key}\"\n");
		}
}

# Close the graph by writing an ending } character
sub close_graph {
	write_to_graph("}\n");
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

################################################################################
#  Main program                                                                #
################################################################################
print "gengraph - gen_folder_deps - Make a graph for dependencies between ";
print "folders\n\n";
&parse_inparameters;
&show_globals if $debug;



&traverse_tree(0, $root_folder);
&print_file_list if $debug;

&parse_files;
&open_dot_file($DOT_FILEHANDLE, "$dotfile\.$dotextension");

&create_graph;
&print_file_list if $debug;

&close_graph($DOT_FILEHANDLE);
&close_dot_file($DOT_FILEHANDLE);

system("cat $script_folder/$dotfile\.$dotextension") if $debug;

&make_graph if $graphviz;

