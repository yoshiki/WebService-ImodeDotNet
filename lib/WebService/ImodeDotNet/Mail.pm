package WebService::ImodeDotNet::Mail;

use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use WebService::ImodeDotNet::Const;
use WebService::ImodeDotNet::Attachment;
use WebService::ImodeDotNet::UserAgent;

__PACKAGE__->mk_accessors( qw( folder_id id recv_type decome_flag subject body
                               time from tos ccs attachments inline_attachments ) );

my $BASE_URL               = 'https://imode.net';
my $JSON_BASE_URL          = $BASE_URL . '/imail/oexaf/acgi';
my $JSON_ATTACHED_FILE_URL = $JSON_BASE_URL . '/mailfileget';
my $JSON_INLINE_FILE_URL   = $JSON_BASE_URL . '/mailimgget';

sub new {
    my $class = shift;
    my %args = @_;
    my $preview_mail = $args{ data }->{ previewMail };
    my $self = bless {
        folder_id          => $args{ folder_id },
        id                 => $args{ mail_id },
        recv_type          => $preview_mail->{ recvType },
        decome_flag        => $preview_mail->{ decomeFlg },
        subject            => $preview_mail->{ subject },
        body               => $preview_mail->{ body },
        time               => $preview_mail->{ time },
        attachments        => [],
        inline_attachments => [],
        tos                => [],
        ccs                => [],
    }, $class;

    my $preview_infos = $preview_mail->{ previewInfo };
    for my $preview_info ( @$preview_infos ) {
        if ( $preview_info->{ type } == TYPE_FROM ) {
            $self->from( $preview_info->{ mladdr } );
        } elsif ( $preview_info->{ type } == TYPE_TO ) {
            push @{ $self->tos }, $preview_info->{ mladdr };
        } elsif ( $preview_info->{ type } == TYPE_CC ) {
            push @{ $self->ccs }, $preview_info->{ mladdr };
        }
    }

    my $attachment_files = $preview_mail->{ attachmentFile };
    for my $attachment_file ( @$attachment_files ) {
        my $attachment = WebService::ImodeDotNet::Attachment->new(
            type => ATTACHMENT_TYPE_ATTACH,
            mail => $self,
            data => $attachment_file->[ 0 ],
        );
        push @{ $self->attachments }, $attachment;
    }

    my $inline_infos = $preview_mail->{ inlineInfo };
    for my $inline_info ( @$inline_infos ) {
        my $attachment = WebService::ImodeDotNet::Attachment->new(
            type => ATTACHMENT_TYPE_INLINE,
            mail => $self,
            data => $inline_info,
        );
        push @{ $self->inline_attachments }, $attachment;
    }

    $self->get_attachment_files;

    return $self;
}

sub get_attachment_files {
    my $self = shift;
    for my $attachment ( @{ $self->attachments }, @{ $self->inline_attachments } ) {
        warn 'Fetching file ' . $attachment->name;
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

        my $mechanize = WebService::ImodeDotNet::UserAgent->new;
        $mechanize->post( $url, $params );

        if (!$mechanize->success) {
            Carp::croak( 'Fetch attachment file failed' );
        }

        $attachment->data( $mechanize->content );
    }
}

1;
