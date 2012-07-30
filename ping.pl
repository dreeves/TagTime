#!/usr/bin/env perl
# Prompt for what you're doing RIGHT NOW.  In the future this should show
# a cool pie chart that lets you click on the appropriate pie slice,
# making that slice grow slightly.  And the slice boundaries could be fuzzy
# to indicate the confidence intervals!  Ooh, and you can drag the
# slices around to change the order so similar things are next to each
# other and it remembers that order for next time!  That's gonna rock.

my $pingTime = time();
my $autotags = "";

require "$ENV{HOME}/.tagtimerc";
require "${path}util.pl";

my $tskf = "$path$usr.tsk";

# if passed a parameter, take that to be timestamp for this ping.
# if not, then this must not have been called by launch. tag as UNSCHED.
$t = shift;
if(!defined($t)) {
  $autotags .= " UNSCHED";
  $t = time();
}

# Can't lock the same lockfile here since launch.pl will have the lock!
# This script may want to lock a separate lock file, just in case multiple
# instances are invoked, but launch.pl will only launch one at a time.
#lockb();  # wait till we can get the lock.

if($pingTime-$t > 9) {
  print divider(""), "\n";
  print divider(" WARNING "x8), "\n";
  print divider(""), "\n";
  print "This popup is ", ($pingTime-$t), " seconds late.\n";
  print <<EOS;
Either you were answering a previous ping when this tried to pop up, or you just
started the tagtime daemon (tagtimed.pl), or your computer's extremely sluggish.
EOS
  print divider(""), "\n\n";
}

# walk through the task file, printing the active tasks and capturing the list
# of tags for each task (capturing in a hash keyed on task number).
# TODO: have a function that takes a reference to a tasknum->tags hash and a
# tasknum->fulltaskline hash and populates those hashes, purging them first.
# that way we we're not duplicating most of this walk through code.  one 
# annoyance: we want to print them in the order they appear in the task file.
# maybe an optional parameter to the function that says whether to print the
# tasks to stdout as you encounter them.
if(-e $tskf) {  # show pending tasks
  open(F, "< $tskf") or die "ERROR-tsk: $!\n";
  while(<F>) {
    if(/^\-{4,}/ || /^x\s/i) { print; last; }
    if(/^(\d+)\s+\S/) {
      print;
      $tags{$1} = gettags($_);  # hash mapping task num to tags string.
    } else { print; }
  }
  close(F);
  print "\n";
}

my($s,$m,$h,$d) = localtime($t);
$s = dd($s); $m = dd($m); $h = dd($h); $d = dd($d);
print "It's tag time!  ",
  "What are you doing RIGHT NOW ($h:$m:$s)?\n\n";
my($resp, $tagstr, $comments, $a);
do {
  $resp = <STDIN>;

  if ($resp =~ /^"\s*/) {

    # Responses for lazy people.  A response string consisting of only
    # a pair of double-quotes means "ditto", and acts as if we entered
    # the last thing that was in our tracking file.

    # TODO - This should really be its own function, and we should
    # write a test case.

    use strict;
    use warnings;

    our $logf;

    use Tie::File;  # For people too lazy to find the last line. :)

    tie(my @logfile, 'Tie::File', $logf)
      or die "Can't open $logf for ditto function - $!";

    my $last = $logfile[-1];

    # TODO: Is there a function to parse tagtime lines?  If so, we should
    # be using it here.

    ($resp) = $last =~ m{
      ^
      \d+        # Timestamp
      \s+        # Spaces after timestamp
      (\S[^[(]*) # Tag info (up until the first paren if present)
    }x;

    $resp or die "Failed to find any tags for ditto function."

  }

  # refetch the task numbers from task file; they may have changed.
  if(-e $tskf) {
    open(F, "< $tskf") or die "ERROR-tsk2: $!\n";
    %tags = ();  # empty the hash first.
    while(<F>) {
      if(/^\-{4,}/ || /^x\s/i) { last; }
      if(/^(\d+)\s+\S/) { $tags{$1} = gettags($_); } 
    }
    close(F);
  }

  $tagstr = trim(strip($resp));
  $comments = trim(stripc($resp));
  $tagstr =~ s/\b(\d+)\b/($tags{$1} eq "" ? "$1" : "$1 ").$tags{$1}/eg;
  $tagstr =~ s/\b(\d+)\b/tsk $1/;
  $tagstr .= $autotags;
  $tagstr =~ s/\s+/\ /g;
  $a = annotime("$t $tagstr $comments", $t)."\n";
} while($enforcenums && $tagstr ne "" && 
        #($tagstr !~ /\b(\d+|non$d|afk)\b/)  # include day of month
        ($tagstr !~ /\b(\d+|non|afk)\b/)
       );
print $a;
slog($a);

# Send your tagtime log to Beeminder if user has @beeminder list non-empty.
#   (maybe should do this after retropings too but launch.pl would do that).
if((%beeminder || @beeminder) && $resp !~ /^\s*$/) {
  # We could show historical stats on the tags for the current ping here.
  print divider(" sending your tagtime data to beeminder "), "\n";
  if(@beeminder) {  # for backward compatibility
    for(@beeminder) { print "$_: "; @tmp = split(/\s+/, $_); bm($tmp[0]); }
  } else {
    for(keys(%beeminder)) { print "$_: "; bm($_); }
  }
}

# Send pings to the given beeminder goal, e.g. passing "alice/foo" sends
# appropriate (as defined in .tagtimerc) pings to bmndr.com/alice/foo
sub bm { my($s) = @_;
  $cmd = "${path}beeminder.pl ${path}$usr.log $s";
  system($cmd) == 0 or print "SYSERR: $cmd\n";
}

