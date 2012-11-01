package WebService::ImodeDotNet::Mail;

use strict;
use warnings;
use base qw( Class::Accessor::Lvalue::Fast );
use WebService::ImodeDotNet::Const;
use WebService::ImodeDotNet::Attachment;

__PACKAGE__->mk_accessors( qw( folder_id id recv_type decome_flag subject body
                               time from tos ccs attachments inline_attachments ) );

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
    }, $class;

    my $preview_infos = $preview_mail->{ previewInfo };
    for my $preview_info ( @$preview_infos ) {
        if ( $preview_info->{ type } == TYPE_FROM ) {
            $self->from = $preview_info->{ mladdr };
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
            type => ATTACHMENT_TYPE_ATTACH,
            mail => $self,
            data => $inline_info->[ 0 ],
        );
        push @{ $self->inline_attachments }, $attachment;
    }

    return $self;
}

1;
