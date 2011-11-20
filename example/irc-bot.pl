#!perl -w
use strict;
use 5.10.0;
use AnySan;
use AnySan::Provider::IRC;
use LLEval;
use Encode qw(encode_utf8 decode_utf8);

use constant _DEBUG => $ENV{LLEVAL_BOT_DEBUG};
use if _DEBUG, 'Data::Dumper';


my $lleval = LLEval->new();

my %languages = %{$lleval->languages};
my $langs     = '(?:' . join('|', map { quotemeta } keys %languages) . ')';

my $irc = irc
    'chat.freenode.net',
    nickname => 'lleval',
    channels => {
        '#soozy'  => { },
        '#lleval' => { },
    };

sub receiver {
    my($r) = @_;
    my($lang, $src) = $r->message =~ /\A ($langs) \s+ (.+)/xms or return;

    say "$lang $src" if _DEBUG;
    my $result = $lleval->call_eval( decode_utf8($src), $lang );

    if(_DEBUG) {
        say Data::Dumper->new([$result])
                ->Indent(1)
                ->Sortkeys(1)
                ->Quotekeys(0)
                ->Useqq(1)
                ->Terse(1)
                ->Dump();
    }

    if(defined(my $s = $result->{stdout})) {
        $r->send_reply($_) for split /\n/, encode_utf8($s);
    }

    # error?
    if($result->{status}) {
        $r->send_reply("$languages{$lang} returned $result->{status}!!");
    }
    if($result->{error}) {
        $r->send_reply("error: $result->{error}");
    }
    if(defined(my $s = $result->{stderr})) {
        $r->send_reply($_) for split /\n/, encode_utf8($s);
    }
}

AnySan->register_listener(
    echo => {
        cb => \&receiver,
    },
);

AnySan->run;
