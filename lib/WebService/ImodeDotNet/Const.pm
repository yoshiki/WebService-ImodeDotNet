package WebService::ImodeDotNet::Const;

use strict;
use warnings;
use base qw( Exporter );

our @EXPORT = qw(
    YES NO
    FOLDER_ID_SENT FOLDER_ID_DRAFT
    TYPE_FROM TYPE_TO TYPE_CC
    ATTACHMENT_TYPE_ATTACH ATTACHMENT_TYPE_INLINE
);

use constant YES => 1;
use constant NO  => 0;

use constant FOLDER_ID_SENT  => 1;
use constant FOLDER_ID_DRAFT => 2;

use constant TYPE_FROM => 0;
use constant TYPE_TO   => 1;
use constant TYPE_CC   => 2;

use constant ATTACHMENT_TYPE_ATTACH => 0;
use constant ATTACHMENT_TYPE_INLINE => 1;

1;
