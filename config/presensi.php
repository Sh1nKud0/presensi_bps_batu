<?php

return [
    'standalone' => env('PRESENSI_STANDALONE', false),
    'domain' => env('PRESENSI_DOMAIN', 'presensi-simasta.bpskotabatu.com'),
    'api_url' => env('PRESENSI_API_URL', 'https://apipresensi.bpskotabatu.com'),
    'google_client_id' => env('PRESENSI_GOOGLE_CLIENT_ID', ''),
    'local_test' => env('PRESENSI_LOCAL_TEST', false),
    'connect_timeout' => 5,
    'timeout' => 40,
];
