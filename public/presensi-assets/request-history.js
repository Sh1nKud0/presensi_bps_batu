export function decisionHistory(groups, { status = '', from = '', to = '' } = {}) {
    return groups.flatMap(({ kind, requests }) => requests.map(row => ({ ...row, kind })))
        .filter(row => ['disetujui', 'ditolak'].includes(row.status_persetujuan)
            && (!status || row.status_persetujuan === status)
            && (!from || String(row.diproses_at ?? row.created_at).slice(0, 10) >= from)
            && (!to || String(row.diproses_at ?? row.created_at).slice(0, 10) <= to))
        .sort((a, b) => (Date.parse(b.diproses_at ?? b.created_at) || 0) - (Date.parse(a.diproses_at ?? a.created_at) || 0) || String(b.id).localeCompare(String(a.id)));
}
