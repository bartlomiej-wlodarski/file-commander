#!/usr/bin/perl

# Spartan Commander

# usage:
#   perl spartan.pl [directory]

use strict;
use warnings;

use Fcntl ':mode';

use constant {
              FILES_PER_PAGE      => 22,    # how many files to display per page
              IGNORE_HIDDEN_FILES => 0,     # true to ignore hidden files and directories
             };

sub get_type_letter {
    my ($path) = @_;

    lstat($path);                 # check the status of path

    my @checks = (
                  sub { [-d _, 'd'] },
                  sub { [-l _, 'l'] },
                  sub { [-p _, 'p'] },
                  sub { [-S _, 'S'] },
                  sub { [-b _, 'B'] },
                  sub { [-c _, 'c'] },
                  sub { [-t _, 't'] },
                 );

    # Find and return the type letter
    foreach my $check (@checks) {
        my ($bool, $letter) = @{$check->()};
        return $letter if $bool;
    }

    return '-';
}

sub get_user_permissions {
    my ($mode) = @_;

    my $user_readable   = '-';
    my $user_writable   = '-';
    my $user_executable = '-';

    if (($mode & S_IRUSR)) {
        $user_readable = 'r';
    }
    if (($mode & S_IWUSR)) {
        $user_writable = 'w';
    }
    if (($mode & S_IXUSR)) {
        $user_executable = 'x';
    }

    return ($user_readable, $user_writable, $user_executable);
}

sub get_group_permissions {
    my ($mode) = @_;

    my $group_readable   = '-';
    my $group_writable   = '-';
    my $group_executable = '-';

    if (($mode & S_IRGRP)) {
        $group_readable = 'r';
    }
    if (($mode & S_IWGRP)) {
        $group_writable = 'w';
    }
    if (($mode & S_IXGRP)) {
        $group_executable = 'x';
    }

    return ($group_readable, $group_writable, $group_executable);
}

sub get_other_permissions {
    my ($mode) = @_;

    my $other_readable   = '-';
    my $other_writable   = '-';
    my $other_executable = '-';

    if (($mode & S_IROTH)) {
        $other_readable = 'r';
    }
    if (($mode & S_IWOTH)) {
        $other_writable = 'w';
    }
    if (($mode & S_IXOTH)) {
        $other_executable = 'x';
    }

    return ($other_readable, $other_writable, $other_executable);
}

sub read_user_input {
    print "Command: ";
    my $cmd = <STDIN>;
    chomp($cmd);    # remove trailing newline
    return $cmd;
}

sub get_files {
    my ($dir) = @_;

    opendir(my $dir_h, $dir) or do {
        warn "Can't open directory <<$dir>>: $!\n";
        return;
    };

    my @files = readdir($dir_h);
    closedir($dir_h);

    return sort { lc($a) cmp lc($b) } @files;
}

sub display_files {
    my ($dir) = @_;

    my @files = get_files($dir);

    if (IGNORE_HIDDEN_FILES) {
        @files = grep { /^\./ ? /^(\.\.|\.)$/ : 1 } @files;
    }

    if (scalar(@files) == 0) {    # no files found
        return;
    }

    my $from  = 0;
    my $count = 0;

    while (1) {
        foreach my $i ($from .. $#files) {

            my $filename = $files[$i];
            my $abs_path = "$dir/$filename";

            my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) =
              lstat($abs_path);

            my $real_readable   = (-r $abs_path) ? 'r' : '-';
            my $real_writable   = (-w $abs_path) ? 'w' : '-';
            my $real_executable = (-x $abs_path) ? 'x' : '-';

            # Format: <no. of file> <permissions> <size> <type letter> <file name>
            printf(
                "%2d. %1s%1s%1s%1s%1s%1s%1s%1s%1s%1s%1s%1s %10d %1s %s\n", $i + 1,
                get_user_permissions($mode),
                get_group_permissions($mode),
                get_other_permissions($mode),
                $real_readable, $real_writable, $real_executable,
                $size, get_type_letter($abs_path), $filename,
            );

            # Make sure all the files fit on the screen
            if (++$count >= FILES_PER_PAGE or $i == $#files) {
                $count = 0;
                $from  = $i + 1;
                last;
            }
        }

        while (1) {
            my $command = read_user_input();

            if ($command eq 'q') {
                print "Exiting...\n";
                exit;
            }
            elsif ($command eq '+') {    # display next portion of files
                last;
            }
            elsif ($command eq '-') {    # display previous portion of files

                $from -= 2 * FILES_PER_PAGE;
                $from = 0 if ($from < 0);

                last;
            }
            elsif ($command eq '$') {    # jump to the end of the list
                $from = scalar(@files) - FILES_PER_PAGE;
                $from = 0 if ($from < 0);
                last;
            }
            elsif ($command eq '^') {    # jump to the beggining of the list
                $from = 0;
                last;
            }
            elsif ($command =~ /^[0-9]+$/) {    # select one file or directory
                my $file     = $files[$command - 1];
                my $abs_path = "$dir/$file";

                if (-d $abs_path) {             # read directory
                    return display_files($abs_path);
                }
                elsif (-x $abs_path) {          # execute script
                    system("\Q$abs_path\E");
                }
                else {                          # file is not executable
                    print "File $command is not executable and is not a directory...\n";
                }
            }
            elsif (-d $command) {
                return display_files($command);
            }
            else {
                print "Invalid command <<$command>>!\n";
            }
        }
    }
}

# Start in a given directory, given as a command-line argument.
# When no directory is given, start in the current directory.

my $dir = defined($ARGV[0]) ? $ARGV[0] : '.';

display_files($dir);
