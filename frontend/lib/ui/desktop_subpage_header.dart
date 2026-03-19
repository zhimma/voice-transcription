import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

double desktopWindowInsetLeft() {
  return defaultTargetPlatform == TargetPlatform.macOS ? 84 : 16;
}

double desktopWindowInsetRight() {
  return defaultTargetPlatform == TargetPlatform.windows ? 140 : 20;
}

class DesktopSubpageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  const DesktopSubpageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: EdgeInsets.only(
        left: desktopWindowInsetLeft(),
        right: desktopWindowInsetRight(),
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        color: Colors.white,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
