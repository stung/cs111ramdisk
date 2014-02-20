#! /usr/bin/perl -w

open(FOO, "osprd.c") || die "Did you delete osprd.c?";
$lines = 0;
$lines++ while defined($_ = <FOO>);
close FOO;

@tests = (
 # This command writes "foo\n" into the first four bytes of the ramdisk,
 # as we can see when we read those bytes back out.
    # 1
    [ 'echo foo | ./osprdaccess -w ; ' .
      './osprdaccess -r 4',
      "foo" ],

 # This command has the same effect, but the "-d 5" option tells the first
 # osprdaccess to wait 5 seconds after opening the ramdisk, but before
 # writing.
    # 2
    [ 'echo foo | ./osprdaccess -w -d 5; ' .
      'sleep 5; ./osprdaccess -r 4;',
      "foo" ],

# write to an offset in next sector
    # 3
    [ './osprdaccess -r 4 -l -d 5 & ; ' .
      'echo bar | ./osprdaccess -w -L',
      "ioctl OSPRDIOCTRYACQUIRE: Device or resource busy" ],


# As we can see when we use TRYACQUIRE.
    # 4
    [ 'echo foo | ./osprdaccess -w -l /dev/osprda /dev/osprda' ,
      "ioctl OSPRDIOCACQUIRE: Resource deadlock avoided" ],

# Locking the same ramdisk twice would cause deadlock!
    # 5
    [ '(echo test1 | ./osprdaccess -w) && ' .
      '(echo test2 | ./osprdaccess -w -o 5) && ' .
      '(./osprdaccess -r 16 | hexdump -C)',
      "00000000 74 65 73 74 31 74 65 73 74 32 0a 00 00 00 00 00 |test1test2......| " .
      "00000010" ],
    );

my($ntest) = 0;

my($sh) = "bash";
my($tempfile) = "lab2test.txt";
my($ntestfailed) = 0;
my($ntestdone) = 0;
my($zerodiskcmd) = "./osprdaccess -w -z";
my(@disks) = ("/dev/osprda", "/dev/osprdb", "/dev/osprdc", "/dev/osprdd");

my(@testarr, $anytests);
foreach $arg (@ARGV) {
    if ($arg =~ /^\d+$/) {
	$anytests = 1;
	$testarr[$arg] = 1;
    }
}

foreach $test (@tests) {

    $ntest++;
    next if $anytests && !$testarr[$ntest];

    # clean up the disk for the next test
    foreach $disk (@disks) {
	`$sh <<< "$zerodiskcmd $disk"`
    }

    $ntestdone++;
    print STDOUT "Starting test $ntest\n";
    my($in, $want) = @$test;
    open(F, ">$tempfile") || die;
    print F $in, "\n";
    print STDERR $in, "\n";
    close(F);
    $result = `$sh < $tempfile 2>&1`;
    $result =~ s|\[\d+\]||g;
    $result =~ s|^\s+||g;
    $result =~ s|\s+| |g;
    $result =~ s|\s+$||;

    next if $result eq $want;
    next if $want eq 'Syntax error [NULL]' && $result eq '[NULL]';
    next if $result eq $want;
    print STDERR "Test $ntest FAILED!\n  input was \"$in\"\n  expected output like \"$want\"\n  got \"$result\"\n";
    $ntestfailed++;
}

unlink($tempfile);
my($ntestpassed) = $ntestdone - $ntestfailed;
print "$ntestpassed of $ntestdone tests passed\n";
exit(0);
