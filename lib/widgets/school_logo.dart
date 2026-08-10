import 'package:flutter/material.dart';

import '../supabase/neis_service.dart';

/// 학교 로고.
///
/// [logoUrl]과 [fallbackUrl]은 비율을 유지해 표시한다. 네트워크를 쓸 수 없거나
/// 이미지가 없으면 로컬 학교 건물 아이콘을 표시한다.
class SchoolLogo extends StatefulWidget {
  final String name;
  final String? logoUrl;
  final String? fallbackUrl;
  final String? homepage;
  final double size;

  const SchoolLogo({
    super.key,
    required this.name,
    required this.logoUrl,
    this.fallbackUrl,
    this.homepage,
    this.size = 44,
  });

  @override
  State<SchoolLogo> createState() => _SchoolLogoState();
}

class _SchoolLogoState extends State<SchoolLogo> {
  static final Map<String, Future<String?>> _officialLogoCache = {};
  String? _officialLogo;

  @override
  void initState() {
    super.initState();
    _resolveOfficialLogo();
  }

  @override
  void didUpdateWidget(covariant SchoolLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homepage != widget.homepage ||
        oldWidget.name != widget.name) {
      _officialLogo = null;
      _resolveOfficialLogo();
    }
  }

  bool get _needsResolution {
    final homepage = widget.homepage?.trim() ?? '';
    if (homepage.isEmpty) return false;
    final supplied = widget.logoUrl?.trim() ?? '';
    if (supplied.isEmpty) return true;
    final host = Uri.tryParse(supplied)?.host.toLowerCase() ?? '';
    return host == 't1.gstatic.com' || host.endsWith('google.com');
  }

  Future<void> _resolveOfficialLogo() async {
    if (!_needsResolution) return;
    final homepage = widget.homepage!.trim();
    final key = '${widget.name}|$homepage';
    final future = _officialLogoCache.putIfAbsent(
      key,
      () => resolveOfficialSchoolLogo(
        schoolName: widget.name,
        homepage: homepage,
      ),
    );
    final result = await future;
    if (mounted && result != null) setState(() => _officialLogo = result);
  }

  Widget _schoolIcon(BuildContext context) => Icon(
    Icons.school_rounded,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    size: widget.size * 0.52,
  );

  Widget _img(String url, Widget onError) => Image.network(
    url,
    width: widget.size * 0.72,
    height: widget.size * 0.72,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => onError,
  );

  @override
  Widget build(BuildContext context) {
    final logo = _officialLogo ?? widget.logoUrl?.trim() ?? '';
    final fallback = widget.fallbackUrl?.trim() ?? '';
    final icon = _schoolIcon(context);
    final content = logo.isEmpty
        ? icon
        : _img(logo, fallback.isEmpty ? icon : _img(fallback, icon));

    return Semantics(
      image: true,
      label: '${widget.name} 학교 로고',
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.size * 0.28),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
