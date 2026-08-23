
require 5;

package I18N::LangTags::List;
use strict;
our ( %Name, %Is_Disrec, $Debug );
our $VERSION = '0.41';

{
    my $seeking = 1;
    my $count   = 0;
    my ( $disrec, $tag, $name );
    my $last_name = '';
    while (<I18N::LangTags::List::DATA>) {
        if ($seeking) {
            $seeking = 0 if m/=for woohah/;
        }
        elsif ( ( $disrec, $tag, $name ) =
            m/(\[?)\{([-0-9a-zA-Z]+)\}(?:\s*:)?\s*([^\[\]]+)/ )
        {
            $name =~ s/\s*[;\.]*\s*$//g;
            next unless $name;
            ++$count;
            print "<$tag> <$name>\n" if $Debug;
            $last_name = $Name{$tag} = $name;
            $Is_Disrec{$tag} = 1 if $disrec;
        }
        elsif (m/[Ff]ormerly \"([-a-z0-9]+)\"/) {
            $Name{$1}      = "$last_name (old tag)" if $last_name;
            $Is_Disrec{$1} = 1;
        }
    }
    die "No tags read??" unless $count;
}

sub name {
    my $tag = lc( $_[0] || return );
    $tag =~ s/^\s+//s;
    $tag =~ s/\s+$//s;

    my $alt;
    if ( $tag =~ m/^x-(.+)/ ) {
        $alt = "i-$1";
    }
    elsif ( $tag =~ m/^i-(.+)/ ) {
        $alt = "x-$1";
    }
    else {
        $alt = '';
    }

    my $subform = '';
    my $name    = '';
    print "Input: {$tag}\n" if $Debug;
    while ( length $tag ) {
        last if $name = $Name{$tag};
        last if $name = $Name{$alt};
        if ( $tag =~ s/(-[a-z0-9]+)$//s ) {
            print "Shaving off: $1 leaving $tag\n" if $Debug;
            $subform = "$1$subform";

            $alt =~ s/(-[a-z0-9]+)$//s && $Debug && print " alt -> $alt\n";
        }
        else {
            print "Aborting on: {$name}{$subform}\n" if $Debug;
            last;
        }
    }
    print "Output: {$name}{$subform}\n" if $Debug;

    return       unless $name;
    return $name unless $subform;
    $subform =~ s/^-//s;
    $subform =~ s/-$//s;
    return "$name (Subform \"$subform\")";
}

sub is_decent {
    my $tag = lc( $_[0] || return 0 );

    return 0
      unless $tag =~ /^(?:  # First subtag
         [xi] | [a-z]{2,3}
      )
      (?:  # Subtags thereafter
         -           # separator
         [a-z0-9]{1,8}  # subtag  
      )*
    $/xs;

    my @supers = ();
    foreach my $bit ( split( '-', $tag ) ) {
        push @supers, scalar(@supers) ? ( $supers[-1] . '-' . $bit ) : $bit;
    }
    return 0 unless @supers;
    shift @supers if $supers[0] =~ m<^(i|x|sgn)$>s;
    return 0 unless @supers;

    foreach my $f ( $tag, @supers ) {
        return 0 if $Is_Disrec{$f};
        return 2 if $Name{$f};
    }
    return 2 if $Name{$tag};
    return 1;
}

1;

__DATA__



# To generate a list of just the two and three-letter codes:

#!/usr/local/bin/perl -w

require 5; # Time-stamp: "2001-03-13 21:53:39 MST"
 # Sean M. Burke, sburke@cpan.org
 # This program is for generating the language_codes.txt file
use strict;
use LWP::Simple;
use HTML::TreeBuilder 3.10;
my $root = HTML::TreeBuilder->new();
my $url = 'http://lcweb.loc.gov/standards/iso639-2/bibcodes.html';
$root->parse(get($url) || die "Can't get $url");
$root->eof();

my @codes;

foreach my $tr ($root->find_by_tag_name('tr')) {
  my @f = map $_->as_text(), $tr->content_list();
  #print map("<$_> ", @f), "\n";
  next unless @f == 5;
  pop @f; # nix the French name
  next if $f[-1] eq 'Language Name (English)'; # it's a header line
  my $xx = splice(@f, 2,1); # pull out the two-letter code
  $f[-1] =~ s/^\s+//;
  $f[-1] =~ s/\s+$//;
  if($xx =~ m/[a-zA-Z]/) {   # there's a two-letter code for it
    push   @codes, [ lc($f[-1]),   "$xx\t$f[-1]\n" ];
  } else { # print the three-letter codes.
    if($f[0] eq $f[1]) {
      push @codes, [ lc($f[-1]), "$f[1]\t$f[2]\n" ];
    } else { # shouldn't happen
      push @codes, [ lc($f[-1]), "@f !!!!!!!!!!\n" ]; 
    }
  }
}

print map $_->[1], sort {; $a->[0] cmp $b->[0] } @codes;
print "[ based on $url\n at ", scalar(localtime), "]\n",
  "[Note: doesn't include IANA-registered codes.]\n";
exit;
__END__

