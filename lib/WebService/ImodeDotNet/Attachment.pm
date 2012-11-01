package WebService::ImodeDotNet::Attachment;

use strict;
use warnings;
use base qw( Class::Accessor::Lvalue::Fast );

__PACKAGE__->mk_accessors( qw( folder_id mail_id drm_flag name id size type ) );

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {
        folder_id => $args{ mail }->folder_id,
        mail_id   => $args{ mail }->id,
        drm_flag  => $args{ data }->{ drmFlg },
        name      => $args{ data }->{ name },
        id        => $args{ data }->{ id },
        size      => $args{ data }->{ size },
        type      => $args{ type },
    }, $class;
    return $self;
}

1;
