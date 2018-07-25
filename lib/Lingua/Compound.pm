package Lingua::Compound;

use warnings;
use strict;
use utf8;

our $VERSION = '0.01';

use List::Util qw(uniq);
use Text::Unidecode qw(unidecode);

use Moose;

has 'words' => (is => 'ro', isa => 'HashRef', default => sub {{}});
has 'comp_words' =>
    (is => 'ro', isa => 'HashRef', required => 1, clearer => 'clear_comp_words', lazy_build => 1);
has 'lang'          => (is => 'ro', isa => 'Str',     default  => 'en');
has 'lang_prefixes' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'lang_suffixes' => (is => 'ro', isa => 'HashRef', required => 1, lazy_build => 1);
has 'norm_func'     => (is => 'rw', isa => 'CodeRef', required => 1, lazy_build => 1);

our $spacing_chars = quotemeta('[];:-(){}<>?!\\|+,/&«»$€₤¥.');

my %default_lang_prefixes = (
    de => {
        ab  => 3,
        an  => 3,
        be  => 3,
        der => 0,
        was => 0,
        ist => 0,
        end => 0,
    },
    en => {},
    pl => {},
    sk => {
        na => 3,
        vy => 3,
        do => 3,
    },
);

my %default_lang_suffixes = (
    de => {
        en   => 3,
        e    => 4,
        n    => 4,
        ion  => 0,
        ion  => 0,
        ung  => 0,
        des  => 0,
        der  => 0,
        den  => 0,
        "'s" => 0,
    },
    en => {s => 3,},
    pl => {},
    sk => {}

);

sub _build_lang_prefixes {
    my ($self) = @_;
    return $default_lang_prefixes{$self->lang};
}

sub _build_lang_suffixes {
    my ($self) = @_;
    return $default_lang_suffixes{$self->lang};
}

sub _build_comp_words {
    my ($self) = @_;
    my $words = $self->words;
    foreach my $word (keys %{$words}) {
        my @comp = $self->_get_compounds($word);
        shift(@comp)
            if (@comp && ($comp[0] eq $word));
        $words->{$word} = \@comp;
    }
    foreach my $word (keys %{$words}) {
        unless (@{$words->{$word}}) {
            delete($words->{$word});
        }
    }
    return $words;
}

sub _build_norm_func {
    my ($self) = @_;
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

sub _get_compounds {
    my ($self, $word) = @_;

    my $words         = $self->words;
    my $lang_prefixes = $self->lang_prefixes;
    my $lang_suffixes = $self->lang_suffixes;
    my @compounds     = (exists($words->{$word}) ? $word : ());
    foreach my $subterm_len (1 .. length($word) - 1) {
        my $part1 = substr($word, 0, $subterm_len);
        next
            if (
            $subterm_len < 3
            && (!$lang_prefixes->{$part1}
                || (length($word) - $subterm_len - $lang_prefixes->{$part1} < 0))
            );
        next if (exists($lang_prefixes->{$part1}) && ($lang_prefixes->{$part1} == 0));
        if (exists($words->{$part1})) {
            my $part2 = substr($word, $subterm_len);
            next
                if (length($part2) < 3
                && (!$lang_suffixes->{$part2} || (length($part1) - $lang_suffixes->{$part2} < 0)));
            next if (exists($lang_suffixes->{$part2}) && ($lang_suffixes->{$part2} == 0));
            unless (exists($lang_suffixes->{$part2})) {
                my @rest_comp = $self->_get_compounds($part2);
                if (@rest_comp) {
                    push(@compounds, (exists($lang_prefixes->{$part1}) ? () : $part1), @rest_comp);
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

sub csv_dump {
    my ($self) = @_;
    my $comp_words = $self->comp_words;
    return join("\n",
        'cword,locked,compounds',
        (map {join(',', $_, 0, join(' ', @{$comp_words->{$_}}))} sort keys %$comp_words),
    );
}

1;

__END__

=head1 NAME

Lingua::Compound - collect/recognise compound words and build dictionary of them

=head1 SYNOPSIS

    my $lcomp = Lingua::Compound->new();
    $lcomp->add_words(qw(ice skate skates iceskates));
    say $lcomp->csv_dump;

=head1 DESCRIPTION

=head1 PROPERTIES

=head1 METHODS

=head2 new()

Object constructor.

=head1 AUTHOR

Jozef Kutej

=cut
