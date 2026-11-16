import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../widgets.dart';

/// Thêm / sửa dự án. Trả về id dự án.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.project});
  final Project? project;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final Project _p;
  late final TextEditingController _name, _location, _price, _size, _comm, _units, _note;
  bool _saving = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    _p = widget.project?.copy() ?? Project(name: '');
    _name = TextEditingController(text: _p.name);
    _location = TextEditingController(text: _p.location);
    _price = TextEditingController(text: _p.price);
    _size = TextEditingController(text: _p.size);
    _comm = TextEditingController(text: _p.commission);
    _units = TextEditingController(text: '${_p.totalUnits}');
    _note = TextEditingController(text: _p.note);
  }

  @override
  void dispose() {
    for (final t in [_name, _location, _price, _size, _comm, _units, _note]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _addImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (picked == null) return;
      final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
      final name = 'p_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy(AppPaths.imageFile(name).path);
      setState(() => _p.images.add(name));
    } catch (e) {
      if (mounted) showSnack(context, 'Không lấy được ảnh');
    }
  }

  int _parseUnits() {
    final n = int.tryParse(digitsOnly(_units.text)) ?? 1;
    return n < 1 ? 1 : n;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập tên dự án');
      return;
    }
    setState(() => _saving = true);
    _p
      ..name = _name.text.trim()
      ..location = _location.text.trim()
      ..price = _price.text.trim()
      ..size = _size.text.trim()
      ..commission = _comm.text.trim()
      ..totalUnits = _parseUnits()
      ..note = _note.text.trim();
    final id = await Store.instance.saveProject(_p);
    if (!mounted) return;
    showSnack(context, 'Đã lưu dự án');
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa dự án' : 'Thêm dự án')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          SectionCard(
            title: 'Ảnh',
            icon: Icons.photo_library,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_p.images.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final img in _p.images)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(AppPaths.imageFile(img),
                                      width: 110,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      cacheWidth: 330,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                          width: 110, height: 110, child: Icon(Icons.broken_image))),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton.filled(
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => setState(() => _p.images.remove(img)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: const Text('Thư viện'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Thông tin',
            icon: Icons.apartment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputField(
                    controller: _name,
                    label: 'Tên dự án *',
                    icon: Icons.apartment,
                    capitalization: TextCapitalization.words),
                InputField(
                    controller: _location, label: 'Vị trí', icon: Icons.place, maxLines: 2),
                InputField(
                    controller: _price,
                    label: 'Giá',
                    icon: Icons.sell,
                    hint: 'VD: 2,5 tỷ hoặc 35 triệu/m²'),
                InputField(
                    controller: _size, label: 'Diện tích', icon: Icons.square_foot, hint: 'VD: 5x20m, 100m²'),
                const FieldLabel('Pháp lý'),
                ChoiceGroup(
                    options: Opt.legals,
                    value: _p.legal,
                    onChanged: (v) => setState(() => _p.legal = v)),
                const SizedBox(height: 14),
                InputField(
                    controller: _comm,
                    label: 'Hoa hồng',
                    icon: Icons.workspace_premium,
                    hint: 'VD: 2% hoặc 50 triệu/căn'),
                InputField(
                  controller: _units,
                  label: 'Số căn / lô đang bán',
                  icon: Icons.inventory_2,
                  keyboard: TextInputType.number,
                  helper: 'Khi khách cọc / chốt, app tự trừ 1 căn',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _p.soldManual,
                  onChanged: (v) => setState(() => _p.soldManual = v),
                  title: const Text('Đánh dấu ĐÃ BÁN HẾT', style: TextStyle(fontSize: 17)),
                ),
                InputField(controller: _note, label: 'Ghi chú', maxLines: 4),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save, size: 26),
            label: const Text('LƯU DỰ ÁN'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(62)),
          ),
        ],
      ),
    );
  }
}
