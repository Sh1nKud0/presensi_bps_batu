<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Mahasiswa;
use Illuminate\Http\Request;

class MahasiswaController extends Controller
{
    /**
     * Menampilkan semua data mahasiswa
     */
    public function index()
    {
        $mahasiswa = Mahasiswa::latest()->get();

        return view('admin.mahasiswa.index', compact('mahasiswa'));
    }

    /**
     * Menampilkan form tambah mahasiswa
     */
    public function create()
    {
        return view('admin.mahasiswa.create');
    }

    /**
     * Menyimpan mahasiswa baru
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:255',
            'nim' => 'required|string|max:50|unique:mahasiswas,nim',
            'email' => 'required|email|max:255|unique:mahasiswas,email',
            'no_telepon' => 'nullable|string|max:20',
            'perguruan_tinggi' => 'required|string|max:255',
            'program_studi' => 'required|string|max:255',
            'semester' => 'nullable|string|max:20',
            'tahun_angkatan' => 'nullable|string|max:20',
            'alamat' => 'nullable|string',
            'kota' => 'nullable|string|max:100',
        ]);

        Mahasiswa::create($validated);

        return redirect('/admin/mahasiswa')
            ->with('success', 'Data mahasiswa berhasil ditambahkan.');
    }

    /**
     * Menampilkan detail mahasiswa
     */
    public function show(Mahasiswa $mahasiswa)
    {
        return view('admin.mahasiswa.show', compact('mahasiswa'));
    }

    /**
     * Menampilkan form edit mahasiswa
     */
    public function edit(Mahasiswa $mahasiswa)
    {
        return view('admin.mahasiswa.edit', compact('mahasiswa'));
    }

    /**
     * Memperbarui data mahasiswa
     */
    public function update(Request $request, Mahasiswa $mahasiswa)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:255',
            'nim' => 'required|string|max:50|unique:mahasiswas,nim,' . $mahasiswa->id,
            'email' => 'required|email|max:255|unique:mahasiswas,email,' . $mahasiswa->id,
            'no_telepon' => 'nullable|string|max:20',
            'perguruan_tinggi' => 'required|string|max:255',
            'program_studi' => 'required|string|max:255',
            'semester' => 'nullable|string|max:20',
            'tahun_angkatan' => 'nullable|string|max:20',
            'alamat' => 'nullable|string',
            'kota' => 'nullable|string|max:100',
        ]);

        $mahasiswa->update($validated);

        return redirect('/admin/mahasiswa')
            ->with('success', 'Data mahasiswa berhasil diperbarui.');
    }

    /**
     * Menghapus mahasiswa
     */
    public function destroy(Mahasiswa $mahasiswa)
    {
        $mahasiswa->delete();

        return redirect('/admin/mahasiswa')
            ->with('success', 'Data mahasiswa berhasil dihapus.');
    }
}