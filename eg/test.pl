#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WebService::ImodeDotNet;
use Config::Pit;
use Encode;
use Data::Dumper;

my $config = pit_get( 'imode.net', require => {
    docomo_id => 'your_docomo_id',
    password  => 'your_password',
} );

my $service = WebService::ImodeDotNet->new(
    docomo_id => $config->{ docomo_id },
    password  => $config->{ password },
);
$service->login;
#$service->get_folders;
while (1) {
    warn 'check...';
    $service->check_new_mail;
    sleep( 30 );
}

#my $folder = $folder_of->{ 0 };
#my $mail_id = $folder->mail_id_list->[ $ARGV[0] ];
#my $mail = $service->get_mail_detail( $folder->id, $mail_id );
#warn Dumper $mail;
