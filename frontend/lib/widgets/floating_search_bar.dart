import 'package:flutter/material.dart';

class FloatingSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onClear;

  const FloatingSearchBar({
    super.key,
    required this.onSearch,
    this.onClear,
  });

  @override
  State<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<FloatingSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      widget.onSearch(query);
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onClear?.call();
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.search,
              color: Colors.grey,
              size: 24,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onTap: () {
                setState(() {
                  _isExpanded = true;
                });
              },
              onSubmitted: (_) => _performSearch(),
              decoration: const InputDecoration(
                hintText: '自然言語で施設を検索（例：美味しいラーメン店）',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (_controller.text.isNotEmpty || _isExpanded) ...[
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(
                Icons.clear,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _performSearch,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}