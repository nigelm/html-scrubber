# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => ';

use Test;
BEGIN { plan tests => 1 };
use HTML::Scrubber;
ok(1);

