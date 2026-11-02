<?php

namespace App\Http\Controllers;

use App\Models\Pengajuan;
use Illuminate\Http\Request;

class PengajuanController extends Controller
{
    // kolom profil yang wajib terisi sebelum mengajukan
    private array $wajibProfil = ['nim', 'perguruan_tinggi', 'program_studi', 'no_telepon'];

    private function profilLengkap($profil): bool
    {
        foreach ($this->wajibProfil as $k) {
            if (empty($profil->$k ?? null)) return false;
        }
        return true;
    }

    public function index()
    {
        $user = auth()->user();

        return view('mahasiswa.pengajuan', [
            'pengajuan'     => $user->pengajuan,
            'profilLengkap' => $this->profilLengkap($user->mahasiswa),
        ]);
    }

    public function store(Request $request)
    {
        $user     = auth()->user();
        $existing = $user->pengajuan;

        if (!$this->profilLengkap($user->mahasiswa)) {
            return redirect('/mahasiswa/profil')
                ->with('error', 'Lengkapi profil dulu sebelum mengajukan magang.');
        }

        // hanya boleh kirim kalau belum pernah, atau sebelumnya ditolak
        if ($existing && $existing->status !== 'ditolak') {
            return redirect('/mahasiswa/pengajuan')
                ->with('error', 'Pengajuanmu sedang diproses.');
        }

        $data = $request->validate([
            'bidang_diminati' => 'required|string|max:150',
            'periode_mulai'   => 'required|date|after_or_equal:today',
            'periode_selesai' => 'required|date|after:periode_mulai',
            'motivasi'        => 'required|string|min:30|max:2000',
            'file_surat'      => 'required|file|mimes:pdf|max:2048',
            'file_cv'         => 'nullable|file|mimes:pdf|max:2048',
        ], [
            'periode_mulai.after_or_equal' => 'Tanggal mulai tidak boleh sebelum hari ini.',
            'periode_selesai.after'        => 'Tanggal selesai harus setelah tanggal mulai.',
            'motivasi.min'                 => 'Motivasi minimal 30 karakter.',
            'file_surat.mimes'             => 'Surat pengantar harus berformat PDF.',
            'file_surat.max'               => 'Ukuran surat pengantar maksimal 2 MB.',
        ]);

        $data['file_surat'] = $request->file('file_surat')->store('pengajuan', 'public');
        if ($request->hasFile('file_cv')) {
            $data['file_cv'] = $request->file('file_cv')->store('pengajuan', 'public');
        }

        $data['instansi']      = 'BPS Kota Batu';
        $data['status']        = 'diproses';
        $data['catatan_admin'] = null;

        Pengajuan::updateOrCreate(['user_id' => $user->id], $data);

        return redirect('/mahasiswa/pengajuan')
            ->with('success', 'Pengajuan berhasil dikirim. Admin akan memeriksa berkasmu.');
    }
}