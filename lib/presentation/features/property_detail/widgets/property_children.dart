import 'package:flutter/material.dart' hide Page;

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../theme/theme.dart';
import '../../discovery/widgets/property_card.dart';
import '../pages/property_detail_page.dart';

class PropertyChildren extends StatefulWidget {
  const PropertyChildren({super.key, required this.propertyId});
  final String propertyId;
  @override
  State<PropertyChildren> createState() => _PropertyChildrenState();
}

class _PropertyChildrenState extends State<PropertyChildren> {
  Page<Property>? _page;
  final List<String?> _cursors = [null];
  int _index = 0;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_request == 0) _load(0);
  }

  Future<void> _load(int index) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await DependenciesScope.of(context).properties.getChildren(
        widget.propertyId,
        PageQuery(limit: 4, cursor: _cursors[index]),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = result;
        _index = index;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error is XlandFailure
            ? error.message
            : 'Không thể tải danh sách lô con.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <Property>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Các lô đất con${_page?.total == null ? '' : ' (${_page!.total})'}',
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: 8),
        const Text('Chọn một lô để xem giá, thông số và hồ sơ chi tiết.'),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(_error!, semanticsLabel: 'Lỗi tải lô con: $_error'),
          TextButton(
            onPressed: () => _load(_index),
            child: const Text('Thử lại'),
          ),
        ] else if (items.isEmpty)
          const Text('Chưa có lô con được công bố.')
        else ...[
          // Rows size to their content, including large accessibility text sizes.
          for (var i = 0; i < items.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = i; j < i + 2; j++) ...[
                    if (j > i) const SizedBox(width: 10),
                    Expanded(
                      child: j >= items.length
                          ? const SizedBox.shrink()
                          : PropertyCard(
                              property: items[j],
                              showBookmark: false,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PropertyDetailPage(
                                    propertyId: items[j].id,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _index > 0 ? () => _load(_index - 1) : null,
                child: const Text('Trang trước'),
              ),
              Text('Trang ${_index + 1}'),
              TextButton(
                onPressed: _page!.hasMore
                    ? () {
                        if (_cursors.length > _index + 1) {
                          _cursors.removeRange(_index + 1, _cursors.length);
                        }
                        _cursors.add(_page!.nextCursor);
                        _load(_index + 1);
                      }
                    : null,
                child: const Text('Trang sau'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
