#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Cwd qw(abs_path);

my $FILE_TYPES 	= '\( -iname ldscript.\* -o -iname \*.c -o -iname \*.h -o -iname \*.s -o -iname \*.S -o -iname \*.cpp -o -iname \*.hpp -o -iname \*.cxx \)';
my $PACKAGE_PATH= '';
my $MAKE_CMD	= '';
my $MOUNT_POINT = '';
my $mount_done  = 0;
my $COMPILED_FILES = 'compiled.files';
my $platform=`uname`;

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
	for my $fp (sort keys %ahash) {
		#print("$ahash{$fp} == $bhash{$fp}\n");
		 if(exists($bhash{$fp})) {
			if ($ahash{$fp} > $bhash{$fp}) {
				push(@clist, $fp);
			}
		} else {
			push(@clist, $fp); # generated file
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
		local $> = 0; # switch as root
		if ($> != 0) {
			print("Error: Run this script with sudo. It does a remount with strictatime/relatime option\n");
			exit 1;
		}
		#print("Root: mounting filesystem\n");
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

sub get_mount_cmd
{
	my $cmd;
	if ($platform eq "FreeBSD") {
		$cmd 	= qq(mount -o atime $MOUNT_POINT);
	} else {
		$cmd 	= qq(mount -o remount,strictatime $MOUNT_POINT);
	}
	return $cmd;
}

sub init
{
	my $cmd = get_mount_cmd();
	my $ret 	= superuser_action($cmd);
	if ($ret) {
		$MOUNT_POINT = '/';
		$cmd 	= get_mount_cmd();
		my $ret 	= superuser_action($cmd);
		if($ret) {
			exit(1);
		}
	}
	$mount_done = 1;
	return $MOUNT_POINT;
}

sub cleanup
{
	if ($mount_done) {
		my $cmd = '';
		if ($platform eq "FreeBSD") {
			$cmd = qq(mount -o noatime $MOUNT_POINT);
		} else {
			$cmd 	= qq(mount -o remount,relatime $MOUNT_POINT);
		}
		superuser_action($cmd);
		$mount_done 	= 0;
		print("Done cleaning up\n");
	}
}

END {
	cleanup();
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
	my ($ppath, $make) = @_;
	if (! -d $ppath) {
		print("Error: Wrong package path : $ppath\n");
		exit 0;
	}
	if ($MOUNT_POINT eq '') {
		$MOUNT_POINT= '/' . (split('/', $ppath))[1];
	}
	$MOUNT_POINT= init();
	my @output 	= run_command(qq(find $ppath $FILE_TYPES));
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
	chomp($platform);
	drop_sudo();
	my $num_args = $#ARGV + 1;
	if ($num_args >= 2) {
		$PACKAGE_PATH = shift @ARGV;
		$MAKE_CMD	  = shift @ARGV;
		if ($num_args > 2) {
			$MOUNT_POINT = shift @ARGV;
		}
		if ($num_args > 3) {
			$COMPILED_FILES= shift @ARGV
		}
		$PACKAGE_PATH = abs_path($PACKAGE_PATH);
		process($PACKAGE_PATH, $MAKE_CMD)
	} else {
		printf ("Uasge: " . __FILE__  . " <src path> <make command> <mount point> <logfilename>\n");
		exit 0;
	}
	my $etime = time();
	my $ttime = $etime - $stime;
	if ($platform eq "FreeBSD") {
		run_command('cat ' . $COMPILED_FILES . ' | xargs ctags');
		run_command('cscope -b -q -k -i ' . $COMPILED_FILES);
	} else {
		run_command('ctags -L ' . $COMPILED_FILES . ' -f .tags');
		run_command('cscope -b -q -k -i ' . $COMPILED_FILES);
	}
	print("Total time taken: $ttime secs\n");
	exit 0;
}

main();
# sudo ./identify.pl $PWD ./build-rpi.sh /dev/da0p2 compiled.files
