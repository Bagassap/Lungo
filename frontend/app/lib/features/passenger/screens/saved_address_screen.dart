import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class _Address {
  final String label, detail;
  final IconData icon;
  final Color iconColor, iconBg;
  const _Address(this.label, this.detail, this.icon, this.iconColor, this.iconBg);
}

class SavedAddressScreen extends StatefulWidget {
  const SavedAddressScreen({super.key});
  @override
  State<SavedAddressScreen> createState() => _SavedAddressScreenState();
}

class _SavedAddressScreenState extends State<SavedAddressScreen> {
  final List<_Address> _addresses = [
    const _Address('Rumah', 'Jl. Melati No. 12, Jakarta Selatan',
        Icons.home_rounded, Color(0xFF0540F2), Color(0xFFE0E8FF)),
    const _Address('Kantor', 'Jl. Sudirman Kav 52, Jakarta Pusat',
        Icons.work_rounded, Color(0xFF059669), Color(0xFFDCFCE7)),
    const _Address('Gym', 'Jl. Rasuna Said, Kuningan',
        Icons.fitness_center_rounded, Color(0xFFD97706), Color(0xFFFEF3C7)),
  ];

  void _addAddress() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur tambah alamat segera hadir',
            style: GoogleFonts.plusJakartaSans()),
        backgroundColor: AppColors.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Column(
          children: [
            _Header(title: 'Alamat Tersimpan'),
            Expanded(
              child: _addresses.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _addresses.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _AddressTile(
                        address: _addresses[i],
                        onDelete: () => setState(() => _addresses.removeAt(i)),
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addAddress,
          backgroundColor: AppColors.primaryColor,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('Tambah Alamat',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFFE0E8FF), shape: BoxShape.circle),
          child: const Icon(Icons.location_off_rounded,
              color: AppColors.primaryColor, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Belum ada alamat tersimpan',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 16,
                color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        Text('Tambahkan alamat favorit Anda',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: const Color(0xFF7B8FC0))),
      ],
    ),
  );
}

class _AddressTile extends StatelessWidget {
  final _Address address;
  final VoidCallback onDelete;
  const _AddressTile({required this.address, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x180540F2), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: address.iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(address.icon, color: address.iconColor, size: 22),
        ),
        title: Text(address.label,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 14,
                color: const Color(0xFF0D1240))),
        subtitle: Text(address.detail,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: const Color(0xFF9AAAD0))),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: Color(0xFFB0BFDF), size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  Text('Edit', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                ])),
            PopupMenuItem(value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFFF6B35)),
                  const SizedBox(width: 8),
                  Text('Hapus', style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: const Color(0xFFFF6B35))),
                ])),
          ],
          onSelected: (v) { if (v == 'delete') onDelete(); },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0B0940), Color(0xFF04198C)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            Expanded(
              child: Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    ),
  );
}
