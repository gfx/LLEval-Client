#!perl -w
use 5.10.0;
use strict;
use AnySan;
use AnySan::Provider::IRC;
use LLEval;
use Encode qw(encode_utf8 decode_utf8);

use constant _DEBUG => $ENV{LLEVAL_BOT_DEBUG};
use if _DEBUG, 'Data::Dumper';

use constant MAX_LINE_LEN => 80;

my($host, @channels) = @ARGV;

$host ||= 'irc.freenode.net';
@channels = ('#lleval') unless @channels;

my $lleval = LLEval->new();

my %languages = %{$lleval->languages};
my $langs     = '(?:' . join('|', 'lleval', map { quotemeta } keys %languages) . ')';

my $irc = irc
    $host,
    nickname => 'lleval',
    channels => {
        map { $_ => +{ } } @channels,
    };

sub cut {
    my($line) = @_;
    return $line if $line < MAX_LINE_LEN;
    return substr $line, 0, MAX_LINE_LEN;
}

sub receiver {
    my($r) = @_;
    my($lang, $src) = $r->message =~ /\A ($langs) \s+ (.+)/xms or return;

    if($lang eq 'lleval') {
        if($src eq 'list') { # `lleval list`
            $r->send_reply(join ' ', sort keys %languages);
        }
        elsif($src =~/\A \s+ (\S+) /xms) { # `lleval $lang`
            my $keyword = $1;
            my $command = $languages{$keyword};
            if(defined $command) {
                $r->send_reply("$keyword is executed by $command");
            }
        }
        else { # `lleval`
            $r->send_reply("lleval is provided by dankogai");
            $r->send_reply("See http://colabv6.dan.co.jp/lleval.html for details");
        }
        return;
    }

    say "$lang $src" if _DEBUG;

    if($lang eq 'pl') {
        $src = 'use 5.12.0; use warnings; use autodie;' . $src;
    }
    my $result = $lleval->call_eval( decode_utf8($src), $lang );

    if(_DEBUG && _DEBUG > 1) {
        say Data::Dumper->new([$result])
                ->Indent(1)
                ->Sortkeys(1)
                ->Quotekeys(0)
                ->Useqq(1)
                ->Terse(1)
                ->Dump();
    }

    if(defined(my $s = $result->{stdout})) {
        $r->send_reply(cut $_) for split /\n/, encode_utf8($s);
    }

    # error?
    if($result->{status}) {
        $r->send_reply(cut "$languages{$lang} returned $result->{status}!!");
    }
    if($result->{error}) {
        $r->send_reply(cut "error: $result->{error}");
    }
    if(defined(my $s = $result->{stderr})) {
        $r->send_reply(cut $_) for split /\n/, encode_utf8($s);
    }
}

AnySan->register_listener(
    echo => {
        cb => \&receiver,
    },
);

AnySan->run;
