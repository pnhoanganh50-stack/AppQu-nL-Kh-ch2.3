import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail_screen.dart';
import 'deal_form_screen.dart';
import 'project_form_screen.dart';

/// Chi tiết dự án: ảnh, thông tin, tình trạng hàng, khách quan tâm, giao dịch.
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final int projectId;

  Future<void> _delete(BuildContext context, Project p) async {
    final ok = await confirm(context, 'Xóa dự án?',
        'Xóa "${p.name}". Khách và giao dịch vẫn được giữ lại.',
        ok: 'Xóa', danger: true);
    if (!ok) return;
    await Store.instance.deleteProject(p);
    if (context.mounted) Navigator.pop(context);
  }

  void _viewImage(BuildContext context, String img) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(child: Image.file(AppPaths.imageFile(img))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.project(projectId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dự án')),
            body: const EmptyView(icon: Icons.apartment, text: 'Dự án không còn tồn tại.'),
          );
        }
        final sold = store.isSoldOut(p);
        final customers = store.customersOfProject(p.id!);
        final deals = store.dealsOfProject(p.id!);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết dự án'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Sửa',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProjectFormScreen(project: p))),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Xóa',
                onPressed: () => _delete(context, p),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              if (p.images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 220,
                    child: PageView(
                      controller: PageController(viewportFraction: 0.92),
                      children: [
                        for (final img in p.images)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => _viewImage(context, img),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(AppPaths.imageFile(img),
                                    fit: BoxFit.cover,
                                    cacheWidth: 1200,
                                    errorBuilder: (_, __, ___) => Container(
                                        color: kNavyLight,
                                        child: const Icon(Icons.broken_image, size: 48))),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sold ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sold ? Colors.red : Colors.green),
                      ),
                      child: Text(
                        sold
                            ? 'ĐÃ BÁN HẾT'
                            : 'Còn ${store.remainingUnits(p)} / ${p.totalUnits} căn (đã bán/cọc ${store.soldUnits(p)})',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: sold ? Colors.red.shade800 : Colors.green.shade800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InfoRow(Icons.place, 'Vị trí', p.location),
                    InfoRow(Icons.sell, 'Giá', p.price),
                    InfoRow(Icons.square_foot, 'Diện tích', p.size),
                    InfoRow(Icons.gavel, 'Pháp lý', p.legal),
                    InfoRow(Icons.workspace_premium, 'Hoa hồng', p.commission),
                    InfoRow(Icons.sticky_note_2, 'Ghi chú', p.note),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        final copy = p.copy()..soldManual = !p.soldManual;
                        store.saveProject(copy);
                      },
                      icon: Icon(p.soldManual ? Icons.undo : Icons.check_circle),
                      label: Text(p.soldManual ? 'Bỏ đánh dấu đã bán' : 'Đánh dấu ĐÃ BÁN HẾT'),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Khách quan tâm (${customers.length})',
                icon: Icons.people,
                child: customers.isEmpty
                    ? const Text('Chưa có khách. Gắn dự án trong trang chi tiết khách.',
                        style: TextStyle(fontSize: 16))
                    : Column(
                        children: [
                          for (final c in customers)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CustomerAvatar(c, radius: 22),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                              subtitle: Text('${c.phone}  ·  ${c.status.label}',
                                  style: const TextStyle(fontSize: 15)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(customerId: c.id!))),
                            ),
                        ],
                      ),
              ),
              SectionCard(
                title: 'Giao dịch (${deals.length})',
                icon: Icons.payments,
                child: deals.isEmpty
                    ? const Text('Chưa có giao dịch.', style: TextStyle(fontSize: 16))
                    : Column(
                        children: [
                          for (final d in deals)
                            DealTile(
                              deal: d,
                              showCustomer: true,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          DealFormScreen(customerId: d.customerId, deal: d))),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
