import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'utils.dart';

/// Nhãn trạng thái có màu.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.big = false});
  final CustomerStatus status;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 4),
      decoration: BoxDecoration(
        color: status.color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: big ? 20 : 16, color: status.color),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w700,
                  fontSize: big ? 17 : 14)),
        ],
      ),
    );
  }
}

class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar(this.customer, {super.key, this.radius = 26});
  final Customer customer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: customer.status.color,
      child: Text(customer.initial,
          style: TextStyle(
              color: Colors.white, fontSize: radius * 0.85, fontWeight: FontWeight.bold)),
    );
  }
}

/// Một dòng khách hàng trong danh sách.
class CustomerTile extends StatelessWidget {
  const CustomerTile({super.key, required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final next = c.nextCall;
    final overdue = next != null && next.isBefore(DateTime.now());
    final summary = c.needSummary;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            children: [
              CustomerAvatar(c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    if (c.phone.isNotEmpty)
                      Text(c.phone,
                          style: TextStyle(fontSize: 17, color: Colors.grey.shade700)),
                    if (summary.isNotEmpty)
                      Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: kNavy)),
                    const SizedBox(height: 6),
                    StatusBadge(c.status),
                    if (next != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.alarm,
                                size: 18, color: overdue ? Colors.red : Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${overdue ? 'Quá hẹn' : c.apptType}: ${fmtFriendly(next)}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: overdue ? Colors.red : Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (c.phone.isNotEmpty)
                IconButton(
                  tooltip: 'Gọi',
                  iconSize: 30,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    minimumSize: const Size(58, 58),
                  ),
                  icon: Icon(Icons.call, color: Colors.green.shade700),
                  onPressed: () => callPhone(context, c.phone),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 68, color: Colors.blueGrey.shade200),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

/// Khung trắng bo góc có tiêu đề.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
  });
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: kGold, size: 26),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(title!,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold, color: kNavy)),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Nhóm nút chọn 1 (bấm lại lần nữa để bỏ chọn nếu [allowEmpty]).
class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allowEmpty = true,
    this.color = kNavy,
  });
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowEmpty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: value == o ? Colors.white : color)),
            selected: value == o,
            showCheckmark: false,
            selectedColor: color,
            backgroundColor: Colors.white,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            onSelected: (_) => onChanged(value == o && allowEmpty ? '' : o),
          ),
      ],
    );
  }
}

/// Tiêu đề nhỏ phía trên một ô nhập / nhóm chọn.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kNavy)),
      );
}

/// Ô nhập chữ dùng chung.
class InputField extends StatelessWidget {
  const InputField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboard,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.validator,
    this.hint,
    this.onChanged,
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboard;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? Function(String?)? validator;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
        textCapitalization: capitalization,
        maxLines: maxLines,
        minLines: 1,
        style: const TextStyle(fontSize: 18),
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperStyle: const TextStyle(fontSize: 15, color: kNavy),
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }
}

/// Một dòng thông tin: biểu tượng + nhãn + giá trị.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.label, this.value, {super.key});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kNavy, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                SelectableText(value, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh đại diện dự án (ảnh đầu tiên), không có ảnh thì hiện biểu tượng.
class ProjectThumb extends StatelessWidget {
  const ProjectThumb(this.project, {super.key, this.size = 72});
  final Project project;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: kNavyLight,
      child: Icon(Icons.apartment, color: kNavy, size: size * 0.5),
    );
    Widget child = placeholder;
    if (project.images.isNotEmpty) {
      child = Image.file(
        AppPaths.imageFile(project.images.first),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
  }
}

/// Nút lớn trên trang chủ.
class BigHomeButton extends StatelessWidget {
  const BigHomeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.background = kNavy,
    this.foreground = Colors.white,
    this.badge,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 44, color: foreground),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.bold, color: foreground)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(fontSize: 15, color: foreground.withAlpha(210))),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: badge! > 0 ? Colors.red.shade600 : Colors.white24,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
