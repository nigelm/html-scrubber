
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Perl extension for scrubbing/sanitizing html",
  "dist_author" => [
    "Ruslan Zakirov <Ruslan.Zakirov\@gmail.com>",
    "Nigel Metheringham <nigelm\@cpan.org>",
    "D. H. <podmaster\@cpan.org>"
  ],
  "dist_name" => "HTML-Scrubber",
  "dist_version" => "0.11",
  "license" => "perl",
  "module_name" => "HTML::Scrubber",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "HTML::Entities" => 0,
    "HTML::Parser" => "3.47",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "Carp" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Scalar::Util" => 0,
    "Test" => 0,
    "Test::More" => "0.94",
    "perl" => "5.004",
    "utf8" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
