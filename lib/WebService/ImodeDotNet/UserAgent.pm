package WebService::ImodeDotNet::UserAgent;

use strict;
use warnings;
use base qw( WWW::Mechanize );

our $COOKIE_FILE = '/tmp/cookie.txt';
our $USER_AGENT  = 'Mozilla/4.0 (compatible;MSIE 7.0; Windows NT 6.0;)';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(
        agent      => $USER_AGENT,
        cookie_jar => HTTP::Cookies->new(
            file           => $COOKIE_FILE,
            autosave       => 1,
            ignore_discard => 1,
        ),
    );
    return $self;
}

sub add_header_for_ajax {
    my $self = shift;
    $self->add_header( 'Accept', '*/*' );
    $self->add_header( 'Accept-Encoding', 'gzip, deflate' );
    $self->add_header( 'Cache-Control', 'no-cache' );
    $self->add_header( 'x-pw-service', 'PCMAIL/1.0' );
    $self->add_header( 'Referer',
                       'https://imode.net/imail/oexaf/ahtm/index_f.html' );
    $self->add_header( 'Content-Type',
                       'application/x-www-form-urlencoded' );
}

1;
