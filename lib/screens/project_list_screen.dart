import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';

/// Danh sách dự án / hàng hóa.
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _search = TextEditingController();
  bool _hideSold = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(int id) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: id)));

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Dự án / Hàng hóa')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await Navigator.push<int>(
              context, MaterialPageRoute(builder: (_) => const ProjectFormScreen()));
          if (id != null && mounted) _open(id);
        },
        icon: const Icon(Icons.add_home_work, size: 28),
        label: const Text('Thêm dự án'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, _search]),
        builder: (context, _) {
          final q = normalize(_search.text);
          final list = store.projects.where((p) {
            if (_hideSold && store.isSoldOut(p)) return false;
            return q.isEmpty || normalize('${p.name} ${p.location}').contains(q);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Tìm tên dự án, vị trí',
                    prefixIcon: Icon(Icons.search, size: 28),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                value: _hideSold,
                onChanged: (v) => setState(() => _hideSold = v),
                title: const Text('Ẩn dự án đã bán hết', style: TextStyle(fontSize: 17)),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyView(
                        icon: Icons.apartment,
                        text: 'Chưa có dự án.\nBấm "Thêm dự án" để nhập hàng đang bán.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _ProjectTile(
                            project: list[i], onTap: () => _open(list[i].id!)),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.onTap});
  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final p = project;
    final sold = store.isSoldOut(p);
    final interested = store.customersOfProject(p.id!).length;
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProjectThumb(p, size: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    if (p.location.isNotEmpty)
                      Text(p.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                    if (p.price.isNotEmpty)
                      Text(p.price,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: kNavy)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tag(
                            sold
                                ? 'ĐÃ BÁN HẾT'
                                : 'Còn ${store.remainingUnits(p)}/${p.totalUnits}',
                            sold ? Colors.red.shade700 : Colors.green.shade700),
                        if (p.legal.isNotEmpty) _tag(p.legal, kNavy),
                        if (interested > 0) _tag('$interested khách quan tâm', const Color(0xFF8A6D10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      );
}
