# perl Makefile.PL && nmake realclean && cls && perl Makefile.PL && nmake test

use strict;
use File::Spec;
use Test::More tests => 10;
BEGIN { $^W = 1 }

                use_ok( 'HTML::Scrubber' );

my $s = HTML::Scrubber->new;
my $html = q[<html><body><p>hi<br>start <!--comment--> mid1 <?html pi> mid2 <?xml pi?> end</body></html>];

                isa_ok($s, 'HTML::Scrubber');

my $tmpdir = File::Spec->tmpdir();

SKIP: {
    skip "no writable temporary directory found", 6
        unless length $tmpdir
            and -d $tmpdir;

    my $tmpfile = File::Spec->catfile($tmpdir,"html-scrubber.test.html");
    my $r = $s->scrub($html,$tmpfile);
    $r = "Error: \$@=$@ \$!=$!" unless $r;
                    is($r, 1, "scrub(\$html,\$tmpfile=$tmpfile)");

#    use Data::Dumper;die Dumper($s);

    local *FILIS;
    open FILIS, "+>$tmpfile" or die "can't write to $tmpfile";

    $r = $s->scrub($html,\*FILIS);
    $r = "Error: \$@=$@ \$!=$!" unless $r;

                    is($r, 1, q[scrub($html,\*FILIS)]);

    seek *FILIS,0,0;
    $r = join '', readline *FILIS;
                    is($r,"histart  mid1  mid2  end","FILIS has the right stuff");
                    is(close(FILIS),1,q[close(FILIS)]);

    $r = $s->scrub_file($tmpfile,"$tmpfile.html");
    $r = "Error: \$@=$@ \$!=$!" unless $r;

                    is($r, 1, qq[scrub_file(\$tmpfile,"\$tmpfile.html"=$tmpfile.html)]);

    open FILIS, "+>$tmpfile.html" or die "can't write to $tmpfile";
    $r = $s->scrub_file($tmpfile,\*FILIS);
    $r = "Error: \$@=$@ \$!=$!" unless $r;

                    is($r, 1, q[scrub_file($tmpfile,\*FILIS)]);
    seek *FILIS,0,0;
    $r = join '', readline *FILIS;
                    is($r,"histart  mid1  mid2  end","FILIS has the right stuff");
                    is(close(FILIS),1,q[close(FILIS)]);

};
