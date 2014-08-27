#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Cwd qw(abs_path);

my $FILE_TYPES 	= 'chsS';
my $PACKAGE_PATH= '/home/syrajendra/Rajendra/projects/personal/package';
my $MAKE_CMD	= 'export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu && make clean && make';
my $mount_done  = 0;
my $home = '';
my $COMPILED_FILES = 'compiled.files';

sub run_command
{
	my $cmd = shift;
	print "Executing CMD: $cmd \n";
	$cmd 		.= ' 2>&1';
	my @output 	 = qx($cmd);
	my $ret_code = $?;
	if ($ret_code & 127 || ($ret_code >> 8)) {
		print "Error: Failed to run cmd : $cmd\n";
		print "Output: @output";
		#exit $ret_code;
		return ($ret_code, @output);
	}
	return (0, @output);
}

sub get_source_access_time
{
	my @output 	= @_;
	my %file_hash  	= ();
	foreach my $filepath (sort @output) {
		chomp($filepath);
		if (!exists($file_hash{$filepath})) {
			my $acctime = (stat($filepath))[8];
			#print("File: $filepath = $acctime\n");
			$file_hash{$filepath} = $acctime;
		} else {
			print("Ignore file: $filepath\n")
		}
	}
	my $count = keys %file_hash;
	printf("Files hashed: $count\n");
	return %file_hash;
}

sub get_compiled_filelist
{
	my $bh 		= shift;
	my $ah 		= shift;
	my %bhash 	= %{$bh};
	my %ahash 	= %{$ah};
	my @clist   = ();
	for my $fp (sort keys %bhash) {
		#print("$ahash{$fp} == $bhash{$fp}\n");
		if ($ahash{$fp} > $bhash{$fp}) {
			push(@clist, $fp);
		}
	}
	return @clist;
}

sub drop_sudo
{
	$> = getpwnam(getlogin()); # updating effective userid
}

sub superuser_action
{
	my $cmd 	= shift;
	#print("Real: $< Effective $>\n");
	{ # root
		local $> = 0;
		if ($> != 0) {
			print("Error: Run this script with sudo. It does a remount with strictatime/relatime option\n");
			exit 1;
		}
		#print("Root: mount filesystem\n");
		my @output 	= run_command($cmd);
		if ($output[0] != 0) {
			print("Error: Failed to mount\n@output\n");
			return 1;
		}
	}
	#print("Drop sudo privileages\n");
	drop_sudo();
	#print("Real: $< Effective $>\n");
	return 0;
}

sub init
{
	my $cmd 	= qq(mount -o remount,strictatime $home);
	my $ret 	= superuser_action($cmd);
	if ($ret) {
		$home = '/';
		$cmd 	= qq(mount -o remount,strictatime $home);
		my $ret 	= superuser_action($cmd);
		if($ret) {
			exit(1);
		}
	}
	$mount_done = 1;
	return $home;
}

sub cleanup
{
	if ($mount_done) {
		my $cmd 	= qq(mount -o remount,relatime $home);
		superuser_action($cmd);
		$mount_done 	= 0;
		print("Done cleaning up\n");
	}
}

END {
	cleanup($home)
}

sub log_data
{
	my ($filename, @list) 	= @_;
	my $logfd;
	open($logfd, '>' . $filename);
	foreach my $line (@list) {
		chomp($line);
		print($logfd "$line\n");
	}
	close($logfd);
}

sub process
{
	my ($ppath, $filetypes, $make) = @_;
	if (! -d $ppath) {
		print("Error: Wrong package path : $ppath\n");
		exit 0;
	}
	$home 		= '/' . (split('/', $ppath))[1];
	$home 		= init($home);
	my @output 	= run_command(qq(find $ppath -name "*.[$filetypes]"));
	my $status 	= shift @output;
	my @f_list	= @output;
	if ($status == 0) {
		if($#output > 0) {
			my %before_hash = get_source_access_time(@f_list);
			sleep(1);
			my $cmd = "cd $ppath && $make";
			my @output = run_command($cmd);
			my $status = shift @output;
			if ($status != 0) {
				print("Error: Failed to compile code. Exiting...\n");
				exit 1;
			}
			log_data('compiled.log', @output);
			my %after_hash 	= get_source_access_time(@f_list);
			my @cf_list = get_compiled_filelist(\%before_hash, \%after_hash);
			print("compiled files: $#cf_list\n");
			log_data($COMPILED_FILES, @cf_list);
		} else {
			printf("Error: Failed to find files of filetype $FILE_TYPES\n");
			exit 1;
		}
	}
}

sub main
{
	my $stime  	= time();
	drop_sudo();
	my $num_args = $#ARGV + 1;
	if ($num_args == 2) {
		$PACKAGE_PATH = shift @ARGV;
		$MAKE_CMD	  = shift @ARGV;
		$PACKAGE_PATH = abs_path($PACKAGE_PATH);
		process($PACKAGE_PATH, $FILE_TYPES, $MAKE_CMD)
	} else {
		printf ("Uasge: " . __FILE__  . " <package_path> <make command>\n");
		exit 0;
	}
	my $etime = time();
	my $ttime = $etime - $stime;
	run_command('ctags -L ' . $COMPILED_FILES . ' -f .tags');
	run_command('cscope -b -q -k -i ' . $COMPILED_FILES);
	print("Total time taken: $ttime secs\n");
	exit 0;
}

main();
