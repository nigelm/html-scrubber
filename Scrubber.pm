
=head1 NAME

HTML::Scrubber - Perl extension for scrubbing/sanitizing html

=head1 SYNOPSIS

=for example begin

    #!/usr/bin/perl -w
    use HTML::Scrubber;
    use strict;
                                                                            #
    my $html = q[
    <style type="text/css"> BAD { background: #666; color: #666;} </style>
    <script language="javascript"> alert("Hello, I am EVIL!");    </script>
    <HR>
        a   => <a href=1>link </a>
        br  => <br>
        b   => <B> bold </B>
        u   => <U> UNDERLINE </U>
    ];
                                                                            #
    my $scrubber = HTML::Scrubber->new( allow => [ qw[ p b i u hr br ] ] ); #
                                                                            #
    print $scrubber->scrub($html);                                          #
                                                                            #
    $scrubber->deny( qw[ p b i u hr br ] );                                 #
                                                                            #
    print $scrubber->scrub($html);                                          #
                                                                            #


=for example end

=head1 DESCRIPTION

If you wanna "scrub" or "sanitize" html input
in a reliable an flexible fashion,
then this module is for you.

I wasn't satisfied with HTML::Sanitizer because it is
based on HTML::TreeBuilder,
so I thought I'd write something similar
that works directly with HTML::Parser.

=head1 METHODS

First a note on documentation: just study the L<EXAMPLE|"EXAMPLE"> below.
It's all the documentation you could need

Also, be sure to read all the comments as well as
L<How does it work?|"How does it work?">.

If you're new to perl, good luck to you.

=cut

package HTML::Scrubber;
use HTML::Parser();
use HTML::Entities;
use vars qw[ $VERSION @_scrub @_scrub_fh ];
use strict;

$VERSION = '0.08';

# my my my my, these here to prevent foolishness like 
# http://perlmonks.org/index.pl?node_id=251127#Stealing+Lexicals
(@_scrub    )= ( \&_scrub, "self, event, tagname, attr, attrseq, text");
(@_scrub_fh )= ( \&_scrub_fh, "self, event, tagname, attr, attrseq, text");

sub new {
    my $package = shift;
    my $p = HTML::Parser->new(
        api_version     => 3,
        default_h       => \@_scrub,
        marked_sections => 0,
        strict_comment  => 0,
        unbroken_text   => 1,
        case_sensitive  => 0,
        boolean_attribute_value => undef,
    );

    my $self = {
        _p => $p,
        _rules => {
            '*' => 0,
        },
        _comment => 0,
        _process => 0,
        _r => "",
        _optimize => 1,
        _script => 0,
        _style  => 0,
    };

    $p->{"\0_s"} = bless $self, $package;

    return $self unless @_;

    my(%args)= @_;

    for my $f( qw[ default allow deny rules process comment ] ) {
        next unless exists $args{$f};
        if( ref $args{$f} ) {
            $self->$f( @{ $args{$f} } ) ;
        } else {
            $self->$f( $args{$f} ) ;
        }
    }

    return $self;
}

=head2 comment

    warn "comments are  ", $p->comment ? 'allowed' : 'not allowed';
    $p->comment(0);  # off by default

=cut

sub comment {
    return
        $_[0]->{_comment}
            if @_ == 1;
    $_[0]->{_comment} = $_[1];
    return;
}

=head2 process

    warn "process instructions are  ", $p->process ? 'allowed' : 'not allowed';
    $p->process(0);  # off by default

=cut


sub process {
    return
        $_[0]->{_process}
            if @_ == 1;
    $_[0]->{_process} = $_[1];
    return;
}


=head2 script

    warn "script tags (and everything in between) are supressed"
        if $p->script;      # off by default
    $p->script( 0 || 1 );

B<**> Please note that this is implemented 
using HTML::Parser's ignore_elements function,
so if C<script> is set to true,
all script tags encountered will be validated like all other tags.

=cut

sub script {
    return
        $_[0]->{_script}
            if @_ == 1;
    $_[0]->{_script} = $_[1];
    return;
}

=head2 style 

    warn "style tags (and everything in between) are supressed"
        if $p->style;       # off by default
    $p->style( 0 || 1 );

B<**> Please note that this is implemented 
using HTML::Parser's ignore_elements function,
so if C<style> is set to true,
all style tags encountered will be validated like all other tags.

=cut

sub style {
    return
        $_[0]->{_style}
            if @_ == 1;
    $_[0]->{_style} = $_[1];
    return;
}

=head2 allow

    $p->allow(qw[ t a g s ]);

=cut

sub allow {
    my $self = shift;
    for my $k(@_){
        $self->{_rules}{lc $k}=1;
    }
    $self->{_optimize} = 1; # each time a rule changes, reoptimize when parse

    return;
}


=head2 deny

    $p->deny(qw[ t a g s ]);

=cut

sub deny {
    my $self = shift;

    for my $k(@_){
        $self->{_rules}{lc $k} = 0;
    }

    $self->{_optimize} = 1; # each time a rule changes, reoptimize when parse

    return;
}

=head2 rules

    $p->rules(
        img => {
            src => qr{^(?!http://)}i, # only relative image links allowed
            alt => 1,                 # alt attribute allowed
            '*' => 0,                 # deny all other attributes
        },
        b => 1,
        ...
    );

=cut

sub rules{
    my $self = shift;
    my(%rules)= @_;
    for my $k(keys %rules) {
        $self->{_rules}{lc $k} = $rules{$k};
    }

    $self->{_optimize} = 1; # each time a rule changes, reoptimize when parse

    return;
}

=head2 default

    print "default is ", $p->default();
    $p->default(1);      # allow tags by default
    $p->default(
        undef,           # don't change
        {                # default attribute rules
            '*' => 1,    # allow attributes by default
        }
    );

=cut

sub default {
    return
        $_[0]->{_rules}{'*'}
            if @_ == 1;

    $_[0]->{_rules}{'*'} = $_[1] if defined $_[1];
    $_[0]->{_rules}{'_'} = $_[2] if defined $_[2] and ref $_[2];
    $_[0]->{_optimize} = 1; # each time a rule changes, reoptimize when parse

    return;
}

=head2 scrub_file

    $html = $scrubber->scrub_file('foo.html');   ## returns giant string
    die "Eeek $!" unless defined $html;  ## opening foo.html may have failed
    $scrubber->scrub_file('foo.html', 'new.html') or die "Eeek $!";
    $scrubber->scrub_file('foo.html', *STDOUT)
        or die "Eeek $!"
            if fileno STDOUT;

=cut

sub scrub_file {
    if(@_ > 2){
        return unless defined $_[0]->_out($_[2]);
    } else {
        $_[0]->{_p}->handler( default => @_scrub );
    }

    $_[0]->_optimize() ;#if $_[0]->{_optimize};

    $_[0]->{_p}->parse_file($_[1]);

    return delete $_[0]->{_r} unless exists $_[0]->{_out};
    delete $_[0]->{_out};
    return 1;
}

=head2 scrub

    print $scrubber->scrub($html);  ## returns giant string
    $scrubber->scrub($html, 'new.html') or die "Eeek $!";
    $scrubber->scrub($html', *STDOUT)
        or die "Eeek $!"
            if fileno STDOUT;


=cut

sub scrub {
    if(@_ > 2){
        return unless defined $_[0]->_out($_[2]);
    } else {
        $_[0]->{_p}->handler( default => @_scrub );
    }

    $_[0]->_optimize();# if $_[0]->{_optimize};

    $_[0]->{_p}->parse($_[1]);
    $_[0]->{_p}->eof();
    
    return delete $_[0]->{_r} unless exists $_[0]->{_out};
    delete $_[0]->{_out};
    return 1;
}


=for comment _out
    $scrubber->_out(*STDOUT) if fileno STDOUT;
    $scrubber->_out('foo.html') or die "eeek $!";

=cut

sub _out {
    my($self, $o ) = @_;

    unless( ref $o and ref \$o ne 'GLOB') {
        local *F;
        open F, ">$o" or return undef;
        binmode F;
        $self->{_out} = *F;
    } else {
        $self->{_out} = $o;
    }

    $self->{_p}->handler( default => @_scrub_fh );

    return 1;
}


=for comment _validate
Uses $self->{_rules} to do attribute validation.
Takes tag, rule('_' || $tag), attrref.

=cut

sub _validate {
    my($s, $t, $r, $a, $as) = @_;
    return "<$t>" unless %$a;

    $r = $s->{_rules}->{$r};
    my %f;

    for my $k( keys %$a ) {
        if( exists $r->{$k} ) {
            if( ref $r->{$k} || length($r->{$k}) > 1 ) {
                $f{$k} = $a->{$k} if $a->{$k} =~ m{$r->{$k}};
            } elsif( $r->{$k} ) {
                $f{$k} = $a->{$k};
            }
        } elsif( exists $r->{'*'} and $r->{'*'} ) {
            $f{$k} = $a->{$k};
        }
    }

    if( %f ){
        my %seen;
        return "<$t $r>"
            if $r = join ' ',
                    map {
                        defined $f{$_}
                        ? qq[$_="].encode_entities($f{$_}).q["]
                        : $_; # boolean attribute (TODO?)
                    } grep {
                        exists $f{$_} and !$seen{$_}++;
                    } @$as;
    }

    return "<$t>";
}

=for comment _scrub_fh
I<default> handler, does the scrubbing if we're scrubbing out to a file.

=cut

sub _scrub_fh {
    my( $p, $e, $t, $a, $as, $text ) = @_;
    my $s = $p->{"\0_s"} ;

    if ( $e eq 'start' )
    {
        if( exists $s->{_rules}->{$t} )  # is there a specific rule
        {
            if( ref $s->{_rules}->{$t} ) # is it complicated?(not simple;)
            { 
                print
                    {$s->{_out}}
                        $s->_validate($t, $t, $a, $as);
            }
            elsif( $s->{_rules}->{$t} ) # validate using default attribute rule
            {
                print
                    {$s->{_out}}
                        $s->_validate($t, '_', $a, $as);
            }
        }
        elsif( $s->{_rules}->{'*'} ) # default allow tags
        {
            print
                {$s->{_out}}
                    $s->_validate($t, '_', $a, $as);
        }
    }
    elsif ( $e eq 'end' )
    {    
        if( exists $s->{_rules}->{$t} )
        {
            print
                {$s->{_out}}
                    "</$t>"
                        if $s->{_rules}->{$t};
                        
        }
        elsif( $s->{_rules}->{'*'} )
        {
        
            print {$s->{_out}} "</$t>";
        }
    }
    elsif ( $e eq 'comment' )
    {
        print
            {$s->{_out}}
                $text
                    if $s->{_comment};
    }
    elsif ( $e eq 'process' )
    {
        print
            {$s->{_out}}
                $text
                    if $s->{_process};
    }
    elsif ( $e eq 'text' or $e eq 'default')
    {
        $text =~ s/</&lt;/g; #https://rt.cpan.org/Ticket/Attachment/8716/10332/scrubber.patch
        $text =~ s/>/&gt;/g;

        print
            {$s->{_out}}
                $text;
    }
}

=for comment _scrub
I<default> handler, does the scrubbing if we're returning a giant string.

=cut

sub _scrub {
    my( $p, $e, $t, $a, $as, $text ) = @_;
    my $s = $p->{"\0_s"} ;

    if ( $e eq 'start' )
    {
        if( exists $s->{_rules}->{$t} )  # is there a specific rule
        {  
            if( ref $s->{_rules}->{$t} ) # is it complicated?(not simple;)
            {
                $s->{_r} .= $s->_validate($t, $t, $a, $as);
            }
            elsif( $s->{_rules}->{$t} )  # validate using default attribute rule
            {
                $s->{_r} .= $s->_validate($t, '_', $a, $as);
            }
        }
        elsif( $s->{_rules}->{'*'} )     # default allow tags
        { 
            $s->{_r} .= $s->_validate($t, '_', $a, $as);
        }
    }
    elsif ( $e eq 'end' )
    {
        if( exists $s->{_rules}->{$t} )
        {
            $s->{_r} .= "</$t>" if $s->{_rules}->{$t};
        }
        elsif( $s->{_rules}->{'*'} )
        {
            $s->{_r} .= "</$t>";
        }
    }
    elsif ( $e eq 'comment' )
    {
        $s->{_r} .= $text if $s->{_comment};
    }
    elsif ( $e eq 'process' )
    {
        $s->{_r} .= $text if $s->{_process};
    }
    elsif ( $e eq 'text' or $e eq 'default')
    {
        $text =~ s/</&lt;/g; #https://rt.cpan.org/Ticket/Attachment/8716/10332/scrubber.patch
        $text =~ s/>/&gt;/g;

        $s->{_r} .= $text;
    }
    elsif ( $e eq 'start_document' )
    {
        $s->{_r} = "";
    }
}

sub _optimize {
    my($self) = @_;

    my( @ignore_elements ) = grep { not $self->{"_$_"} } qw(script style);
    $self->{_p}->ignore_elements(@ignore_elements); # if @ is empty, we reset ;)

    return unless $self->{_optimize};
#sub allow
#    return unless $self->{_optimize}; # till I figure it out (huh)

    if( $self->{_rules}{'*'} ){       # default allow
        $self->{_p}->report_tags();   # so clear it
    } else {

        my(@reports) =
            grep {                # report only tags we want
                $self->{_rules}{$_}
            } keys %{
                $self->{_rules}
            };

        $self->{_p}->report_tags( # default deny, so optimize
            @reports
        ) if @reports;
    }

# sub deny
#    return unless $self->{_optimize}; # till I figure it out (huh)
    my(@ignores)= 
        grep {
            not $self->{_rules}{$_}
        } grep {
            $_ ne '*'
        } keys %{
            $self->{_rules}
        };

    $self->{_p}->ignore_tags( # always ignore stuff we don't want
        @ignores
    ) if @ignores;

    $self->{_optimize}=0;
    return;
}


sub DESTROY {
    delete $_[0]->{_p}->{"\0_s"}; # break circular reference
}
1;

#print sprintf q[ '%-12s => %s,], "$_'", $h{$_} for sort keys %h;# perl!
#perl -ne"chomp;print $_;print qq'\t\t# test ', ++$a if /ok\(/;print $/" test.pl >test2.pl
#perl -ne"chomp;print $_;if( /ok\(/ ){s/\#test \d+$//;print qq'\t\t# test ', ++$a }print $/" test.pl >test2.pl
#perl -ne"chomp;if(/ok\(/){s/# test .*$//;print$_,qq'\t\t# test ',++$a}else{print$_}print$/" test.pl >test2.pl

=head1 How does it work?

When a tag is encountered, HTML::Scrubber
allows/denies the tag using the explicit rule if one exists.

If no explicit rule exists, Scrubber applies the default rule.

If an explicit rule exists,
but it's a simple rule(1),
the default attribute rule is applied.

=head2 EXAMPLE

=for example begin

    #!/usr/bin/perl -w
    use HTML::Scrubber;
    use strict;
                                                                            #
    my @allow = qw[ br hr b a ];
                                                                            #
    my @rules = (
        script => 0,
        img => {
            src => qr{^(?!http://)}i, # only relative image links allowed
            alt => 1,                 # alt attribute allowed
            '*' => 0,                 # deny all other attributes
        },
    );
                                                                            #
    my @default = (
        0   =>    # default rule, deny all tags
        {
            '*'           => 1, # default rule, allow all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
    #   If your perl doesn't have qr
    #   just use a string with length greater than 1
            'cite'        => '(?i-xsm:^(?!(?:java)?script))',
            'language'    => 0,
            'name'        => 1, # could be sneaky, but hey ;)
            'onblur'      => 0,
            'onchange'    => 0,
            'onclick'     => 0,
            'ondblclick'  => 0,
            'onerror'     => 0,
            'onfocus'     => 0,
            'onkeydown'   => 0,
            'onkeypress'  => 0,
            'onkeyup'     => 0,
            'onload'      => 0,
            'onmousedown' => 0,
            'onmousemove' => 0,
            'onmouseout'  => 0,
            'onmouseover' => 0,
            'onmouseup'   => 0,
            'onreset'     => 0,
            'onselect'    => 0,
            'onsubmit'    => 0,
            'onunload'    => 0,
            'src'         => 0,
            'type'        => 0,
        }
    );
                                                                            #
    my $scrubber = HTML::Scrubber->new();
    $scrubber->allow( @allow );
    $scrubber->rules( @rules ); # key/value pairs
    $scrubber->default( @default );
    $scrubber->comment(1); # 1 allow, 0 deny
                                                                            #
    ## preferred way to create the same object
    $scrubber = HTML::Scrubber->new(
        allow   => \@allow,
        rules   => \@rules,
        default => \@default,
        comment => 1,
        process => 0,
    );
                                                                            #
    require Data::Dumper,die Data::Dumper::Dumper($scrubber) if @ARGV;
                                                                            #
    my $it = q[
        <?php   echo(" EVIL EVIL EVIL "); ?>    <!-- asdf -->
        <hr>
        <I FAKE="attribute" > IN ITALICS WITH FAKE="attribute" </I><br>
        <B> IN BOLD </B><br>
        <A NAME="evil">
            <A HREF="javascript:alert('die die die');">HREF=JAVA &lt;!&gt;</A>
            <br>
            <A HREF="image/bigone.jpg" ONMOUSEOVER="alert('die die die');"> 
                <IMG SRC="image/smallone.jpg" ALT="ONMOUSEOVER JAVASCRIPT">
            </A>
        </A> <br> 
    ];
                                                                            #
    print "#original text",$/, $it, $/;
    print
        "#scrubbed text (default ",
        $scrubber->default(), # no arguments returns the current value
        " comment ",
        $scrubber->comment(),
        " process ",
        $scrubber->process(),
        " )",
        $/,
        $scrubber->scrub($it),
        $/;
                                                                            #
    $scrubber->default(1); # allow all tags by default
    $scrubber->comment(0); # deny comments
                                                                            #
    print
        "#scrubbed text (default ",
        $scrubber->default(),
        " comment ",
        $scrubber->comment(),
        " process ",
        $scrubber->process(),
        " )",
        $/,
        $scrubber->scrub($it),
        $/;
                                                                            #
    $scrubber->process(1);        # allow process instructions (dangerous)
    $default[0] = 1;              # allow all tags by default
    $default[1]->{'*'} = 0;       # deny all attributes by default
    $scrubber->default(@default); # set the default again
                                                                            #
    print
        "#scrubbed text (default ",
        $scrubber->default(),
        " comment ",
        $scrubber->comment(),
        " process ",
        $scrubber->process(),
        " )",
        $/,
        $scrubber->scrub($it),
        $/;

=for example end


=head2 FUN

If you have Test::Inline (and you've installed HTML::Scrubber), try

    pod2test Scrubber.pm >scrubber.t
    perl scrubber.t

=head1 SEE ALSO

L<HTML::Parser>, L<Test::Inline>, L<HTML::Sanitizer>.

=head1 BUGS/SUGGESTIONS/ETC

Please use
https://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML-Scrubber
to report I<bugs>/additions/etc
or send mail to <bug-HTML-Scrubber#rt.cpan.org>.

=head1 AUTHOR

D. H. (PodMaster)

=head1 LICENSE

Copyright (c) 2003-2004 by D.H. (PodMaster). All rights reserved.

This module is free software;
you can redistribute it and/or modify it under
the same terms as Perl itself.
The LICENSE file contains the full text of the license.

=cut
