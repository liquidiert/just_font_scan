import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'just_font_scan Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const FontListPage(),
    );
  }
}

class FontListPage extends StatefulWidget {
  const FontListPage({super.key});

  @override
  State<FontListPage> createState() => _FontListPageState();
}

class _FontListPageState extends State<FontListPage> {
  List<FontFamily> _families = const [];
  List<FontFamily> _filtered = const [];
  final _searchController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() {
    setState(() => _loading = true);
    final results = JustFontScan.scan();
    setState(() {
      _families = results;
      _filtered = results;
      _loading = false;
    });
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _families
          : _families.where((f) => f.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('System Fonts (${_filtered.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              JustFontScan.clearCache();
              _searchController.clear();
              _scan();
            },
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search font family...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final family = _filtered[index];
                      return _FontFamilyTile(family: family);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FontFamilyTile extends StatelessWidget {
  final FontFamily family;
  const _FontFamilyTile({required this.family});

  String _styleLabel(FontStyle s) {
    switch (s) {
      case FontStyle.regular:
        return 'Regular';
      case FontStyle.bold:
        return 'Bold';
      case FontStyle.italic:
        return 'Italic';
      case FontStyle.boldItalic:
        return 'Bold Italic';
      case FontStyle.unknown:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group fonts by style
    final Map<FontStyle, List<Font>> grouped = {};
    for (final f in family.children) {
      grouped.putIfAbsent(f.style, () => []).add(f);
    }

    // Stable ordering of styles
    final styleOrder = [
      FontStyle.regular,
      FontStyle.bold,
      FontStyle.italic,
      FontStyle.boldItalic,
      FontStyle.unknown,
    ];

    return ListTile(
      title: Text(family.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final style in styleOrder)
            if (grouped.containsKey(style))
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Style label column
                    SizedBox(
                      width: 120,
                      child: Text(
                        _styleLabel(style),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Chips for fonts of this style
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: grouped[style]!
                            .map(
                              (f) => Tooltip(
                                message: "Path: ${f.filePath}",
                                child: Chip(
                                  label: Text(
                                    '${f.weight}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
