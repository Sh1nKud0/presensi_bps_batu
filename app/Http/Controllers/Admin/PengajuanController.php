<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Pengajuan;
use Illuminate\Http\Request;

class PengajuanController extends Controller
{
    // daftar pengajuan + filter status + pencarian
    public function index(Request $request)
    {
        $query = Pengajuan::with('user.mahasiswa')->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('q')) {
            $q = $request->q;
            $query->whereHas('user', function ($u) use ($q) {
                $u->where('name', 'like', "%{$q}%")
                  ->orWhere('email', 'like', "%{$q}%");
            });
        }

        return view('admin.pengajuan.index', [
            'daftar' => $query->paginate(10)->withQueryString(),
            'hitung' => [
                'semua'        => Pengajuan::count(),
                'diproses'     => Pengajuan::where('status', 'diproses')->count(),
                'diverifikasi' => Pengajuan::where('status', 'diverifikasi')->count(),
                'diterima'     => Pengajuan::where('status', 'diterima')->count(),
                'ditolak'      => Pengajuan::where('status', 'ditolak')->count(),
            ],
        ]);
    }

    // detail satu pengajuan
    public function show(Pengajuan $pengajuan)
    {
        $pengajuan->load('user.mahasiswa');

        return view('admin.pengajuan.show', compact('pengajuan'));
    }

    // diproses -> diverifikasi
    public function verifikasi(Pengajuan $pengajuan)
    {
        if ($pengajuan->status === 'diproses') {
            $pengajuan->update(['status' => 'diverifikasi']);
        }

        return back()->with('success', 'Berkas ditandai terverifikasi.');
    }

    // -> diterima (membuka menu terkunci mahasiswa)
    public function terima(Request $request, Pengajuan $pengajuan)
    {
        if (!in_array($pengajuan->status, ['diproses', 'diverifikasi'])) {
            return back()->with('error', 'Pengajuan ini tidak bisa diterima.');
        }

        $data = $request->validate([
            'bidang'     => 'required|string|max:150',
            'pembimbing' => 'required|string|max:150',
        ], [
            'bidang.required'     => 'Bidang penempatan wajib diisi.',
            'pembimbing.required' => 'Pembimbing lapangan wajib diisi.',
        ]);

        $pengajuan->update($data + ['status' => 'diterima', 'catatan_admin' => null]);

        return redirect('/admin/pengajuan')
            ->with('success', "Pengajuan {$pengajuan->user->name} diterima.");
    }

    // -> ditolak
    public function tolak(Request $request, Pengajuan $pengajuan)
    {
        if (!in_array($pengajuan->status, ['diproses', 'diverifikasi'])) {
            return back()->with('error', 'Pengajuan ini tidak bisa ditolak.');
        }

        $data = $request->validate([
            'catatan_admin' => 'required|string|min:5|max:1000',
        ], [
            'catatan_admin.required' => 'Alasan penolakan wajib diisi.',
            'catatan_admin.min'      => 'Alasan penolakan minimal 5 karakter.',
        ]);

        $pengajuan->update([
            'status'        => 'ditolak',
            'catatan_admin' => $data['catatan_admin'],
        ]);

        return redirect('/admin/pengajuan')
            ->with('success', "Pengajuan {$pengajuan->user->name} ditolak.");
    }
}