<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // ADMIN
        User::create([
            'name' => 'Admin SIMASTA',
            'email' => 'admin@simasta.test',
            'password' => Hash::make('admin12345'),
            'role' => 'admin',
        ]);

        // PEMBIMBING
        User::create([
            'name' => 'Pembimbing Lapangan',
            'email' => 'pembimbing@simasta.test',
            'password' => Hash::make('pembimbing123'),
            'role' => 'pembimbing',
        ]);
    }
}