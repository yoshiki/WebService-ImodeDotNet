package WebService::ImodeDotNet::Folder;

use strict;
use warnings;
use base qw( Class::Accessor::Lvalue::Fast );

__PACKAGE__->mk_accessors( qw( id mail_id_list ) );

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {
        id           => $args{ data }->{ folderId },
        mail_id_list => [ sort { $b <=> $a } @{ $args{ data }->{ mailIdList } } ],
    }, $class;
    return $self;
}

1;
