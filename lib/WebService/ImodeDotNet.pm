package WebService::ImodeDotNet;
use strict;
use warnings;
use base qw( Class::Accessor::Lvalue::Fast );
use Carp;
use WWW::Mechanize;
use HTTP::Cookies;
use JSON::Syck;
use Data::Dumper;
use WebService::ImodeDotNet::Folder;
use WebService::ImodeDotNet::Mail;
use WebService::ImodeDotNet::Const;

our $VERSION = '0.01';

__PACKAGE__->mk_accessors( qw( docomo_id password mechanize logged_in folder_of ) );

my $USER_AGENT             = 'Mozilla/4.0 (compatible;MSIE 7.0; Windows NT 6.0;)';
my $BASE_URL               = 'https://imode.net';
my $TOP_URL                = $BASE_URL . '/cmn/top/';
my $LOGIN_URL              = $BASE_URL . '/dcm/dfw';
my $JSON_BASE_URL          = $BASE_URL . '/imail/oexaf/acgi';
my $JSON_LOGIN_URL         = $JSON_BASE_URL . '/login';
my $JSON_MAIL_ID_LIST_URL  = $JSON_BASE_URL . '/mailidlist';
my $JSON_MAIL_DETAIL_URL   = $JSON_BASE_URL . '/maildetail';
my $JSON_ATTACHED_FILE_URL = $JSON_BASE_URL . '/mailfileget';
my $JSON_INLINE_FILE_URL   = $JSON_BASE_URL . '/mailimgget';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {
        docomo_id => $args{ docomo_id },
        password  => $args{ password },
        mechanize => _mechanize(),
        logged_in => NO,
    }, $class;
    return $self;
}

sub _mechanize {
    return WWW::Mechanize->new(
        agent      => $USER_AGENT,
        cookie_jar => HTTP::Cookies->new(
            file           => '/tmp/cookie.txt',
            autosave       => 1,
            ignore_discard => 1,
        ),
    );
}

sub add_header_for_ajax {
    my $self = shift;
    $self->mechanize->add_header( 'Accept', '*/*' );
    $self->mechanize->add_header( 'Accept-Encoding', 'gzip, deflate' );
    $self->mechanize->add_header( 'Cache-Control', 'no-cache' );
    $self->mechanize->add_header( 'x-pw-service', 'PCMAIL/1.0' );
    $self->mechanize->add_header( 'Referer',
                                  'https://imode.net/imail/oexaf/ahtm/index_f.html' );
    $self->mechanize->add_header( 'Content-Type',
                                  'application/x-www-form-urlencoded' );
}

sub login {
    my $self = shift;
    $self->mechanize->get( $TOP_URL );
    $self->mechanize->submit_form(
        form_name => 'form',
        fields => {
            HIDEURL  => '?WM_AK=https%3a%2f%2fimode.net%2fag&path=%2fimail%2ftop&query=',
            LOGIN    => 'WM_LOGIN',
            WM_KEY   => 0,
            MDCM_UID => $self->docomo_id,
            MDCM_PWD => $self->password,
        },
    );
    if ( !$self->mechanize->success ) {
        Carp::croak('Login failed');
    } elsif ( $self->mechanize->content =~ '<title>認証エラー' ) {
        Carp::croak( 'Authorization error' );
    }

    $self->add_header_for_ajax;
    $self->mechanize->post( $JSON_LOGIN_URL );
    if ( !$self->mechanize->success ) {
        Carp::croak( 'Login for ajax failed' );
    }

    $self->logged_in = YES;

    return $self;
}

sub get_folders {
    my $self = shift;
    $self->login if !$self->logged_in;

    $self->add_header_for_ajax;
    $self->mechanize->post( $JSON_MAIL_ID_LIST_URL );
    if ( !$self->mechanize->success ) {
        Carp::croak( 'Fetch mail id list failed' );
    }

    my $data = JSON::Syck::Load( $self->mechanize->content );
    if ( $data->{ common }->{ result } ne 'PW1000' ) {
        Carp::croak( 'Bad response' );
    }

    my %folder_of;
    for my $folder ( @{ $data->{ data }->{ folderList } } ) {
        my $f = WebService::ImodeDotNet::Folder->new( data => $folder );
        $folder_of{ $f->id } = $f;
    }
    $self->folder_of = \%folder_of;

    return $self->folder_of;
}

sub get_mail_detail {
    my ( $self, $folder_id, $mail_id ) = @_;
    $self->login if !$self->logged_in;

    $self->add_header_for_ajax;
    $self->mechanize->post( $JSON_MAIL_DETAIL_URL, {
        'folder.id'      => $folder_id,
        'folder.mail.id' => $mail_id,
    } );

    if ( !$self->mechanize->success ) {
        Carp::croak( 'Fetch mail id list failed' );
    }

    my $data = JSON::Syck::Load( $self->mechanize->content );
    if ( $data->{ common }->{ result } ne 'PW1000' ) {
        Carp::croak( 'Bad response' );
    }

    my $mail = WebService::ImodeDotNet::Mail->new(
        folder_id => $folder_id,
        mail_id   => $mail_id,
        data      => $data->{ data },
    );

    return $mail;
}

sub get_attachment_file {
    my ( $self, $attachment ) = @_;
    if ( $attachment->drm_flag == 1 ) {
        warn "Cannot download an attachment because of the digital rights management";
        return;
    }

    my $params = {
        'folder.id'      => $attachment->folder_id,
        'folder.mail.id' => $attachment->mail_id,
        cdflg            => 0,
    };
    if ( $attachment->type == ATTACHMENT_TYPE_ATTACH ) {
        $params->{ 'folder.attach.id' } = $attachment->id;
    } else {
        $params->{ 'folder.mail.img.id' } = $attachment->id;
    }

    my $url = ( $attachment->type == ATTACHMENT_TYPE_ATTACH )
            ? $JSON_ATTACHED_FILE_URL
            : $JSON_INLINE_FILE_URL;
    $self->mechanize->post( $url, $params );
    return $self->mechanize->content;
}

sub sent_folder {
    my $self = shift;
    $self->login if !$self->logged_in;
    $self->get_folders if $self->folder_of->{ FOLDER_ID_SENT };
    return $self->folder_of->{ FOLDER_ID_SENT };
}

sub draft_folder {
    my $self = shift;
    $self->login if !$self->logged_in;
    $self->get_folders if $self->folder_of->{ FOLDER_ID_DRAFT };
    return $self->folder_of->{ FOLDER_ID_DRAFT };
}

1;
__END__

=head1 NAME

WebService::ImodeDotNet -

=head1 SYNOPSIS

  use WebService::ImodeDotNet;

=head1 DESCRIPTION

WebService::ImodeDotNet is

=head1 AUTHOR

Yoshiki Kurihara E<lt>kurihara at cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
