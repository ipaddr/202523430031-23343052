import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _userSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            // Kolom Pencarian Premium
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _userSearchQuery = val.trim().toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari nama pengguna atau stasiun...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF22D3EE)),
                  fillColor: const Color(0xFF11172A).withValues(alpha: 0.8),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFF22D3EE).withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFF22D3EE).withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 1.2),
                  ),
                ),
              ),
            ),
            
            // Aliran Data Pengguna Secara Realtime
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Tidak Ada Pengguna',
                      subtitle: 'Belum ada pengguna terdaftar pada platform.',
                    );
                  }

                  final allUsers = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String nama = (data['nama'] ?? '').toString().toLowerCase();
                    final String email = (data['email'] ?? '').toString().toLowerCase();
                    return nama.contains(_userSearchQuery) || email.contains(_userSearchQuery);
                  }).toList();

                  if (allUsers.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Pencarian Kosong',
                      subtitle: 'Tidak ada pengguna yang cocok dengan kueri Anda.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: allUsers.length,
                    itemBuilder: (context, index) {
                      final doc = allUsers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name = data['nama'] ?? 'Tanpa Nama';
                      final String email = data['email'] ?? '';
                      final String role = (data['role'] ?? 'user').toString().toUpperCase();
                      final String phone = data['noHp'] ?? '-';
                      final String status = data['status'] ?? 'active';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11172A).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (role == 'ADMIN' ? const Color(0xFFC084FC) : const Color(0xFF22D3EE)).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                role == 'ADMIN' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                color: role == 'ADMIN' ? const Color(0xFFC084FC) : const Color(0xFF22D3EE),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (role == 'ADMIN' ? const Color(0xFFC084FC) : const Color(0xFF22D3EE)).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          role,
                                          style: TextStyle(
                                            color: role == 'ADMIN' ? const Color(0xFFC084FC) : const Color(0xFF22D3EE),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('HP: $phone', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: status == 'pending' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (status == 'pending' ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: status == 'pending' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF22D3EE), size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
