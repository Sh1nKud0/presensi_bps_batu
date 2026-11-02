<?php

namespace App\Http\Controllers;

use App\Models\Mahasiswa;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    public function show()
    {
        $user = auth()->user();

        return view('mahasiswa.profil', [
            'user' => $user,
            'mhs'  => $user->mahasiswa,
        ]);
    }

    public function update(Request $request)
    {
        $user     = auth()->user();
        $existing = $user->mahasiswa;

        $data = $request->validate([
            'foto'             => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
            'jenis_kelamin'    => 'nullable|in:Laki-laki,Perempuan',
            'no_telepon'       => 'nullable|string|max:20',
            'perguruan_tinggi' => 'nullable|string|max:150',
            'program_studi'    => 'nullable|string|max:150',
            'alamat_kampus'    => 'nullable|string',
            'kecamatan_kampus' => 'nullable|string|max:100',
            'kelurahan_kampus' => 'nullable|string|max:100',
            'nim'              => ['nullable', 'string', 'max:30',
                                   Rule::unique('mahasiswas', 'nim')->ignore($existing?->id)],
            'semester'         => 'nullable|integer|min:1|max:14',
            'dosen_pembimbing' => 'nullable|string|max:150',
        ], [
            'foto.image' => 'File harus berupa gambar.',
            'foto.mimes' => 'Foto harus berformat JPG, PNG, atau WEBP.',
            'foto.max'   => 'Ukuran foto maksimal 2 MB.',
            'nim.unique' => 'NIM ini sudah terdaftar pada akun lain.',
        ]);

        // simpan foto baru, hapus foto lama
        if ($request->hasFile('foto')) {
            if ($existing && $existing->foto) {
                Storage::disk('public')->delete($existing->foto);
            }
            $data['foto'] = $request->file('foto')->store('foto-profil', 'public');
        } else {
            unset($data['foto']); // jangan timpa foto lama dengan null
        }

        // sinkronkan nama & email supaya tabel admin tetap terisi
        $data['nama']  = $user->name;
        $data['email'] = $user->email;

        Mahasiswa::updateOrCreate(['user_id' => $user->id], $data);

        return redirect('/mahasiswa/profil')->with('success', 'Profil berhasil diperbarui.');
    }
}