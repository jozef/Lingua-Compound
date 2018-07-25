#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    use_ok('Lingua::Compound') or exit;
}

subtest 'basic lang => en' => sub {
    my $lcomp = Lingua::Compound->new();
    $lcomp->add_words(qw(ice skate skates iceskates rollerskate roller));
    eq_or_diff(
        $lcomp->comp_words(),
        {   skates    => ['skate'],
            iceskates => ['ice', 'skates', 'skate'],
            rollerskate => ['roller', 'skate'],
        },
        'skates compounds',
    );
};

subtest 'basic lang => de' => sub {
    my $lcomp = Lingua::Compound->new();
    $lcomp->add_words(
        'Bodenstaubsauger ist Staubsauger für Boden staubsaugen',
        'alternativ Standstaubsauger im Stand',
        'oder Akkusauger ist Sauger mit Akku',
        'alles um den Staub zu wegsaugen oder weg richten',
    );
    eq_or_diff(
        $lcomp->comp_words(),
        {   bodenstaubsauger => [qw(boden staubsauger staub sauger)],
            standstaubsauger => [qw(stand staubsauger staub sauger)],
            staubsauger      => [qw(staub sauger)],
            akkusauger       => [qw(akku sauger)],
        },
        'staubsauger compounds'
    );
    eq_or_diff(
        $lcomp->csv_dump(),
        join("\n",
            "cword,locked,compounds",
            "akkusauger,0,akku sauger",
            "bodenstaubsauger,0,boden staubsauger staub sauger",
            "standstaubsauger,0,stand staubsauger staub sauger",
            "staubsauger,0,staub sauger",
        ),
        '->csv_dump()',
    );
};

subtest 'units' => sub {
    my $lcomp = Lingua::Compound->new();
    $lcomp->add_words(
        qw(4.5kg 4.5 kg 450kilos 450 kilos 200pounds 200p ounds six sixpounds of pounds 15.7" 15.7 " 123 456 123456)
    );
    eq_or_diff(
        $lcomp->comp_words(),
        {'sixpounds' => [qw(six pounds)],},
        'words with number in the beginning are skipped',
    );
};

done_testing();
