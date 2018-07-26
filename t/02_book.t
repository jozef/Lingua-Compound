#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;
use Path::Class qw(file dir);
use Lingua::Compound;

use FindBin qw($Bin);
use lib "$Bin/lib";

my $book_file = file($Bin, '500-Ratsel-und-Ratselscherze.txt');
plan skip_all =>
    'needs a book file in place: `curl https://www.gutenberg.org/files/31281/31281-0.txt -o t/500-Ratsel-und-Ratselscherze.txt`'
    unless -f $book_file;

subtest 'process t/500-Ratsel-und-Ratselscherze.txt' => sub {
    my $lcomp = Lingua::Compound->new(lang => 'de');
    $lcomp->add_words($book_file->slurp(iomode => '<:encoding(UTF-8)'));
    $lcomp->add_words('ratsel');
    cmp_ok(scalar(keys %{$lcomp->words}), '>', 4_000, 'a book with many different words');

    eq_or_diff($lcomp->comp_words->{schwarzwaldkreis}, [qw(schwarz wald kreis)],
        'schwarzwaldkreis');
    eq_or_diff(
        $lcomp->comp_words->{wohlbekannte},
        [qw(wohl bekannte bekannt wohlbekannt)],
        'wohlbekannte'
    );
    eq_or_diff($lcomp->comp_words->{silberhorn},    [qw(silber horn)],           'silberhorn');
    eq_or_diff($lcomp->comp_words->{ratselscherze}, [qw(ratsel scherze scherz)], 'ratselscherze');
    eq_or_diff($lcomp->comp_words->{wasser}, undef, 'wasser');
};

done_testing();
