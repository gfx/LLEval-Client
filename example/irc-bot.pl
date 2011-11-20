#!perl -w
use strict;
use 5.14.0;
use AnySan;
use AnySan::Provider::IRC;
use LLEval;
use Data::Dumper;

my $lleval = LLEval->new();

my %languages = %{$lleval->languages};
my $langs     = '(?:' . join('|', map { quotemeta } keys %languages) . ')';

my $irc = irc
    'chat.freenode.net',
    nickname => 'lleval',
    channels => {
        '#lleval' => { },
    };

sub receiver {
    my($r) = @_;
    my($lang, $src) = $r->message =~ /\A ($langs) \s+ (.+)/xms or return;

    say "$lang $src";
    my $result = $lleval->call_eval($src, $lang);

    say Data::Dumper->new([$result])
            ->Indent(1)
            ->Sortkeys(1)
            ->Quotekeys(0)
            ->Useqq(1)
            ->Terse(1)
            ->Dump();

    # reply
    if(defined(my $s = $result->{stdout})) {
        $r->send_reply($_) for split /\n/, $s;
    }


    if($result->{status} != 0) {
        $r->send_reply("$languages{$lang} returned $result->{status}!!");
    }
    if(defined(my $s = $result->{stderr})) {
        $r->send_reply($_) for split /\n/, $s;
    }
}

AnySan->register_listener(
    echo => {
        cb => \&receiver,
    },
);

AnySan->run;
