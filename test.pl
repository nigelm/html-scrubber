# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 70 };
use HTML::Scrubber;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.


my $html = q[
    <HR Align="left">
    <B> bold
        <U> underlined
            <I>
                <A href='#"'>  LINK    </A>
            </I>
        </U>
    </B>
    <!-- comments -->
];

my $scrubber = HTML::Scrubber->new();

ok( $scrubber );
ok( ! $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );
ok( ! $scrubber->allow( qw[ p b i u hr br ] ) );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber !~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber !~ /\Q<!--\E/ );

$scrubber = HTML::Scrubber->new( deny => [ qw[ p b i u hr br ] ] );

ok( $scrubber );
ok( ! $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber !~ /[><]/ );
ok( $scrubber !~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber !~ /\Q<!--\E/ );

$scrubber = HTML::Scrubber->new( default => [ 0 ] );

ok( $scrubber );
ok( ! $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber !~ /[><]/ );
ok( $scrubber !~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber !~ /\Q<!--\E/ );

$scrubber = HTML::Scrubber->new( default => [ 1 ] );

ok( $scrubber );
ok( $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber =~ /[><]/ );
ok( $scrubber !~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber !~ /\Q<!--\E/ );

$scrubber = HTML::Scrubber->new( default => [ 1 ] );

ok( $scrubber );
ok( $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );
ok( ! $scrubber->comment(1) );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber =~ /[><]/ );
ok( $scrubber !~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber =~ /\Q<!--\E/ );



$scrubber = HTML::Scrubber->new( default => [ 1 => { align => 1, '*' => 0 } ] );

ok( $scrubber );
ok( $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );
ok( ! $scrubber->comment(1) );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber =~ /[><]/ );
ok( $scrubber !~ /href/i );
ok( $scrubber =~ /Align/i );
ok( $scrubber =~ /\Q<!--\E/ );
ok( $scrubber =~ /"left"/ );

$scrubber = HTML::Scrubber->new( default => [ 1 => { align => 0, '*' => 1 } ] );

ok( $scrubber );
ok( $scrubber->default() );
ok( ! $scrubber->comment() );
ok( ! $scrubber->process() );
ok( ! $scrubber->comment(1) );

$scrubber = $scrubber->scrub($html);

ok( $scrubber );
ok( $scrubber =~ /[><]/ );
ok( $scrubber =~ /href/i );
ok( $scrubber !~ /Align/i );
ok( $scrubber =~ /\Q<!--\E/ );
ok( $scrubber =~ /\Q&quot\E/ );
ok( $scrubber =~ /\#/ );


