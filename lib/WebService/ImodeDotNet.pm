package WebService::ImodeDotNet;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use Carp;
use WWW::Mechanize;
use HTTP::Cookies;
use JSON::Syck;
use Data::Dumper;
use Email::Send;
use Email::Send::Gmail;
use Email::Simple;

use WebService::ImodeDotNet::Folder;
use WebService::ImodeDotNet::Mail;
use WebService::ImodeDotNet::Const;
use WebService::ImodeDotNet::UserAgent;

our $VERSION = '0.01';

__PACKAGE__->mk_accessors( qw( docomo_id password mechanize logged_in folder_of
                               last_mail_id ) );

our $BASE_URL               = 'https://imode.net';
our $TOP_URL                = $BASE_URL . '/cmn/top/';
our $LOGIN_URL              = $BASE_URL . '/dcm/dfw';
our $JSON_BASE_URL          = $BASE_URL . '/imail/oexaf/acgi';
our $JSON_LOGIN_URL         = $JSON_BASE_URL . '/login';
our $JSON_MAIL_ID_LIST_URL  = $JSON_BASE_URL . '/mailidlist';
our $JSON_MAIL_DETAIL_URL   = $JSON_BASE_URL . '/maildetail';
our $JSON_ATTACHED_FILE_URL = $JSON_BASE_URL . '/mailfileget';
our $JSON_INLINE_FILE_URL   = $JSON_BASE_URL . '/mailimgget';

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {
        docomo_id    => $args{ docomo_id },
        password     => $args{ password },
        mechanize    => WebService::ImodeDotNet::UserAgent->new,
        logged_in    => NO,
        last_mail_id => -1, # initial
    }, $class;

    if ( -f $WebService::ImodeDotNet::UserAgent::COOKIE_FILE ) {
        $self->logged_in( YES ); # maybe
    }

    return $self;
}

sub login {
    my $self = shift;
    return if $self->logged_in;

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

    $self->mechanize->add_header_for_ajax;
    $self->mechanize->post( $JSON_LOGIN_URL );
    if ( !$self->mechanize->success ) {
        Carp::croak( 'Login for ajax failed' );
    }

    $self->logged_in( YES );
}

sub get_folders {
    my $self = shift;
    $self->login if !$self->logged_in;

    $self->mechanize->add_header_for_ajax;
    $self->mechanize->post( $JSON_MAIL_ID_LIST_URL );
    if ( !$self->mechanize->success ) {
        Carp::croak( 'Fetch mail id list failed' );
    }

    my $data = eval { JSON::Syck::Load( $self->mechanize->content ) };
    if ( $@ ) {
        $self->logged_in( NO );
        $self->login;
        return $self->get_folders;
    }

    if ( $data->{ common }->{ result } ne 'PW1000' ) {
        Carp::croak( 'Bad response' );
    }

    my %folder_of;
    for my $folder ( @{ $data->{ data }->{ folderList } } ) {
        my $f = WebService::ImodeDotNet::Folder->new( data => $folder );
        $folder_of{ $f->id } = $f;
    }
    $self->folder_of( \%folder_of );

    # set last_mail_id when first load
    warn $self->folder_of->{ 0 }->mail_id_list->[ 0 ];
    $self->last_mail_id( $self->folder_of->{ 0 }->mail_id_list->[ 0 ] )
        if $self->last_mail_id == -1;

    return $self->folder_of;
}

sub get_mail_detail {
    my ( $self, $folder_id, $mail_id ) = @_;
    $self->login if !$self->logged_in;

    $self->mechanize->add_header_for_ajax;
    $self->mechanize->post( $JSON_MAIL_DETAIL_URL, {
        'folder.id'      => $folder_id,
        'folder.mail.id' => $mail_id,
    } );

    if ( !$self->mechanize->success ) {
        Carp::croak( 'Fetch mail id list failed' );
    }

    my $data = eval { JSON::Syck::Load( $self->mechanize->content ) };
    if ( $@ ) {
        $self->logged_in( NO );
        $self->login;
        return $self->get_folders;
    }

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

sub check_new_mail {
    my $self = shift;
    $self->login if !$self->logged_in;

    $self->get_folders;

    my $folder = $self->folder_of->{ 0 };
    my @new_arrival_mail_ids;
    for my $mail_id ( @{ $folder->mail_id_list } ) {
        if ( $mail_id > $self->last_mail_id ) {
            push @new_arrival_mail_ids, $mail_id;
        }
    }
    return unless @new_arrival_mail_ids;

    @new_arrival_mail_ids = sort { $b <=> $a } @new_arrival_mail_ids;
    $self->last_mail_id( $new_arrival_mail_ids[ 0 ] );

    for my $mail_id ( @new_arrival_mail_ids ) {
        my $mail = $self->get_mail_detail( $folder->id, $mail_id );
        $self->send_mail( $mail );
    }
}

sub send_mail {
    my ( $self, $mail ) = @_;

    my $email = Email::Simple->create(
        header => [
            From    => $mail->from,
            To      => '',
            Subject => $mail->subject,
        ],
        body => $mail->body,
    );

    my $sender = Email::Send->new( {
        mailer => 'Gmail',
        mailer_args => [
            username => '',
            password => '',
        ],
    } );
    eval { $sender->send( $email ) };
    die "Error sending email: $@" if $@;
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
