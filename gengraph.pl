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
my $folder_view = 0;

my $DOT_FILEHANDLE;

my %existing_files;
my %existing_folders;
my %folder_dependencies;

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
		} elsif ($arg =~ m/^-f$/) {
			$folder_view = 1;
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
	print "folder_view: $folder_view\n";
	print "\n";
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

sub is_file_known {
	my $file_to_check = $_[0];
	if ($existing_files{$file_to_check}) {
		print "File exist on path $existing_files{$file_to_check}\n" if $debug;
		return 1;
	}
	return 0;
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
	open $_[0], ">$_[1]", or die $!;
}

sub close_dot_file {
	close $_[0];
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
			open FILE, "<$existing_files{$file}/$file" or die $!;
			my @include_files = grep /#include/, <FILE>;
			foreach my $include_line (@include_files) {
				chomp($include_line);

				if ($include_line =~ m/^ *#include *[<"](.*)[">].*$/) {
					# print "  $file includes $1\n";
					$key =~ s/\.\///g;
					if (is_file_known($1)) {
						my @splitted_folder = split(/\//, $existing_files{$1});
						if (scalar(@splitted_folder) == 2) {
							print "  adding $key -> $splitted_folder[1]\n"
								if $debug;
							push(@{$folder_dependencies{$key}},
									$splitted_folder[1]);
						} else {
							print "  adding $key -> Root\n"
								if $debug;
							push(@{$folder_dependencies{$key}}, "Root");
						}
# push(@{$folder_dependencies{$key}}, $file);
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
&generate_file_lists($root_folder);

&open_dot_file($DOT_FILEHANDLE, "$dotfile\.$dotextension");

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
