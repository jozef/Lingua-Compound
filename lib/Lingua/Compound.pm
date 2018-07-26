package Lingua::Compound;

use warnings;
use strict;
use utf8;

our $VERSION = '0.01';

use List::Util qw(uniq);
use Text::Unidecode qw(unidecode);
use Text::CSV_XS;

use Moose;

has 'words' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'comp_words' =>
    (is => 'ro', isa => 'HashRef', required => 1, clearer => 'clear_comp_words', lazy_build => 1);
has 'lang'          => (is => 'ro', isa => 'Str',     default  => 'en');
has 'prefixes' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'suffixes' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'short_words' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'norm_func'     => (is => 'rw', isa => 'CodeRef', required => 1, lazy_build => 1);

our $spacing_chars = quotemeta('"[];:-(){}<>?!\\|+,/&«»$€₤¥.').q{'};

my %default_prefixes = (
    de => {
        ab  => 4,
        an  => 4,
        be  => 5,
        aus => 4,
    },
    en => {
    },
    pl => {},
    sk => {
        na => 3,
        vy => 3,
        do => 3,
    },
);

my %default_suffixes = (
    de => {
        en   => 3,
        e    => 4,
        n    => 4,
    },
    en => {s => 3,},
    pl => {},
    sk => {}

);

my %default_short_words = (
    de => {
        elle => 0,
        ends => 0,
    },
    en => {
        ice => 4,
        six => 4,
    },
    pl => {},
    sk => {}

);

sub _build_prefixes {
    my ($self) = @_;
    return $default_prefixes{$self->lang};
}

sub _build_suffixes {
    my ($self) = @_;
    return $default_suffixes{$self->lang};
}

sub _build_short_words {
    my ($self) = @_;
    my %short_words = %{$default_short_words{$self->lang}};
    my $prefixes = $self->prefixes;
    my $suffixes = $self->suffixes;
    foreach my $word (keys %{$prefixes}) {
        next unless $prefixes->{$word};
        $short_words{$word} = $prefixes->{$word};
    }
    foreach my $word (keys %{$suffixes}) {
        next unless $suffixes->{$word};
        $short_words{$word} = $suffixes->{$word};
    }
    return $default_short_words{$self->lang};
}

sub _build_comp_words {
    my ($self) = @_;
    my $words      = $self->words;
    my %comp_words;
    foreach my $word (keys %{$words}) {
        my @comp = $self->_get_compounds($word);
        shift(@comp)
            if (@comp && ($comp[0] eq $word));
        $comp_words{$word} = \@comp;
    }
    foreach my $word (keys %comp_words) {
        unless (@{$comp_words{$word}}) {
            delete($comp_words{$word});
        }
    }
    return \%comp_words;
}

sub _build_norm_func {
    return sub {
        my ($phrase) = @_;
        $phrase = lc(unidecode($phrase));
        $phrase =~ s{[_\x{200b}\x{ad}]}{}g
            ;    # underscore is only visual space, zero width space, softhyphen can be removed
        $phrase =~ s{[$spacing_chars]}{ }g;    # spacing chars like spaces
        $phrase =~ s/\s{2,}/ /g;               # consolidate spaces
        $phrase =~ s/^\s+//;                   # consolidate spaces
        $phrase =~ s/\s+$//;                   # consolidate spaces
        return $phrase;
    };
}

sub _build_words {
    my ($self) = @_;
    my $lang = $self->lang;
    my %words
        = ( map { $_ => undef }
            ( keys %{ $default_prefixes{$lang} }, keys %{ $default_suffixes{$lang} } )
        );
    return \%words;
}

sub _get_compounds {
    my ($self, $word) = @_;

    my $words         = $self->words;
    my $prefixes = $self->prefixes;
    my $suffixes = $self->suffixes;
    my $short_words = $self->short_words;
    my @compounds     = (exists($words->{$word}) ? $word : ());
    foreach my $subterm_len (1 .. length($word) - 1) {
        my $part1 = substr($word, 0, $subterm_len);
        next
            if (
            $subterm_len < 3
            && (!$prefixes->{$part1}
                || (length($word) - $subterm_len - $prefixes->{$part1} < 0))
            );
        next if (exists($prefixes->{$part1}) && ($prefixes->{$part1} == 0));
        if (($subterm_len == 3) || exists($short_words->{$part1})) {
            next unless $short_words->{$part1};
            next if ( length($word) - $subterm_len - $short_words->{$part1} < 0 );
        }
        if (exists($words->{$part1})) {
            my $part2 = substr($word, $subterm_len);
            next
                if (length($part2) < 3
                && (!$suffixes->{$part2} || (length($part1) - $suffixes->{$part2} < 0)));
            next if (exists($suffixes->{$part2}) && ($suffixes->{$part2} == 0));
            if ((length($part2) == 3) || exists($short_words->{$part2})) {
                next unless $short_words->{$part2};
                next if ( length($part1) - $short_words->{$part2} < 0 );
            }
            unless (exists($suffixes->{$part2})) {
                my @rest_comp = $self->_get_compounds($part2);
                if (@rest_comp) {
                    push(@compounds, (exists($prefixes->{$part1}) ? () : $part1), @rest_comp);
                }
            }
            else {
                push(@compounds, $part1);
            }
        }
    }

    return uniq @compounds;
}

sub add_words {
    my ($self, @words) = @_;
    my $words = $self->words;
    foreach my $word (map {split(/\s+/, $_)} map {$self->norm_func->($_)} @words) {
        next if $word =~ m/^\d/;    # skip words starting with numbers
        $words->{$word} = ();
    }
    $self->clear_comp_words;
    return $self;
}

sub as_tsv {
    my ($self) = @_;
    my $comp_words = $self->comp_words;
    my $csv = Text::CSV_XS->new ({ binary => 1, quote_char => '"', sep_char => "\t" });
    return join("\n",
        map { $csv->combine(@$_); $csv->string; }
        [qw(cword locked compounds)],
        (map { [ $_, 0, join(' ', @{$comp_words->{$_}}) ]} sort keys %$comp_words),
    );
}

sub as_pm {
    my ($self, $pm_name) = @_;
    $pm_name //= 'DUMMY';

    return q{# generated by Lingua::Compound
package }.$pm_name.q{;
use strict;use warnings;
use Text::CSV_XS;

our %comp_words;
do {
    my $csv  = Text::CSV_XS->new( { binary => 1, quote_char => '"', sep_char => "\t" } );
    my $hline = <DATA>;
    $csv->parse($hline);
    my @cols = $csv->fields;
    my $row  = {};
    $csv->bind_columns( \@{$row}{@cols} );
    while ( my $line = <DATA> ) {
        $csv->parse($line);
        $comp_words{$row->{cword}} = {
            locked => $row->{locked},
            compounds  => $row->{compounds},
        };
    }
};

\%comp_words;

}.qq{__DATA__\n}.$self->as_tsv;
}

1;

__END__

=head1 NAME

Lingua::Compound - collect/recognise compound words and build dictionary of them

=head1 SYNOPSIS

    my $lcomp = Lingua::Compound->new();
    $lcomp->add_words(qw(ice skate skates iceskates));
    say $lcomp->as_tsv;

=head1 DESCRIPTION

=head1 PROPERTIES

=head1 METHODS

=head2 new()

Object constructor.

=head1 AUTHOR

Jozef Kutej

=cut
