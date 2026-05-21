import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Production-safe text widget with copy, call, and SMS actions.
///
/// - Long-press (mobile/web mobile) or right-click (web desktop) triggers actions.
/// - When [isPhoneNumber] is true, a popup menu offers Copy / Call / Message.
/// - When [isPhoneNumber] is false, long-press/right-click instantly copies.
///
/// Usage:
///   CopyableText('Patient Name')                          // instant copy
///   CopyableText('9876543210', isPhoneNumber: true)       // copy + call + sms
class CopyableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool isPhoneNumber;

  const CopyableText(
    this.text, {
    super.key,
    this.style,
    this.overflow,
    this.maxLines,
    this.isPhoneNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: isPhoneNumber
          ? (details) => _showActionMenu(context, details.globalPosition)
          : (_) => _copyToClipboard(context, text),
      onSecondaryTapDown: isPhoneNumber
          ? (details) => _showActionMenu(context, details.globalPosition)
          : (_) => _copyToClipboard(context, text),
      child: Text(
        text,
        style: style,
        overflow: overflow,
        maxLines: maxLines,
      ),
    );
  }

  void _showActionMenu(BuildContext context, Offset position) {
    if (text.isEmpty) return;

    // Capture messenger before async gap to avoid context-after-dispose issues
    final messenger = ScaffoldMessenger.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      items: [
        _menuItem('copy', Icons.copy, 'Copy', Colors.grey.shade700),
        _menuItem('call', Icons.call, 'Call', Colors.green.shade600),
        _menuItem('sms', Icons.message, 'Message', Colors.blue.shade600),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: text));
          messenger.showSnackBar(_copySnackBar(text));
          break;
        case 'call':
          _launchUri(messenger, 'tel');
          break;
        case 'sms':
          _launchUri(messenger, 'sms');
          break;
      }
    });
  }

  static PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  /// Strips non-digit characters (except leading +) for tel/sms URIs.
  String get _cleanedNumber {
    final hasLeadingPlus = text.trimLeft().startsWith('+');
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
  }

  Future<void> _launchUri(ScaffoldMessengerState messenger, String scheme) async {
    final number = _cleanedNumber;
    if (number.isEmpty) return;
    try {
      final uri = Uri(scheme: scheme, path: number);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final label = scheme == 'tel' ? 'dialer' : 'messaging app';
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open $label'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
          width: 300,
        ),
      );
    }
  }

  // ── Shared copy logic (also used by non-phone fields) ──

  static void _copyToClipboard(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(_copySnackBar(text));
  }

  static SnackBar _copySnackBar(String text) {
    return SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.copy, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Copied: $text',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      duration: const Duration(seconds: 2),
      width: 300,
    );
  }
}
