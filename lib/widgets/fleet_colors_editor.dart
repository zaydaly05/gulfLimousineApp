import 'package:flutter/material.dart';

import '../models/fleet.dart';
import '../l10n/locale_service.dart';

/// Admin editor for a car model's colours and how many cars of each.
///
/// Reports every change through [onChanged]; the parent validates with
/// [Fleet.validate] and saves. Styled for the dark admin screens.
class FleetColorsEditor extends StatefulWidget {
  const FleetColorsEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final List<FleetColor> initial;
  final ValueChanged<List<FleetColor>> onChanged;

  @override
  State<FleetColorsEditor> createState() => _FleetColorsEditorState();
}

class _FleetRow {
  _FleetRow(String name, this.count) : name = TextEditingController(text: name);
  final TextEditingController name;
  int count;
}

class _FleetColorsEditorState extends State<FleetColorsEditor> {
  late final List<_FleetRow> _rows = widget.initial.isEmpty
      ? [_FleetRow('', 1)]
      : [for (final c in widget.initial) _FleetRow(c.name, c.count)];

  @override
  void dispose() {
    for (final r in _rows) {
      r.name.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows) FleetColor(name: r.name.text.trim(), count: r.count),
  ]);

  void _setCount(_FleetRow row, int value) {
    setState(() => row.count = value.clamp(0, 999));
    _emit();
  }

  void _add() {
    setState(() => _rows.add(_FleetRow('', 1)));
    _emit();
  }

  void _remove(_FleetRow row) {
    setState(() => _rows.remove(row));
    row.name.dispose();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final total = _rows.fold<int>(0, (sum, r) => sum + r.count);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('fleetColoursAndNumberOf'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                carCount(total),
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.name,
                      onChanged: (_) => _emit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('colourEGBlack'),
                        hintStyle: const TextStyle(color: Colors.white38),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('oneLess'),
                    onPressed: row.count > 0
                        ? () => _setCount(row, row.count - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.white70,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${row.count}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('oneMore'),
                    onPressed: () => _setCount(row, row.count + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.white70,
                  ),
                  IconButton(
                    tooltip: tr('removeColour'),
                    onPressed: _rows.length > 1 ? () => _remove(row) : null,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, color: Colors.orange),
              label: Text(
                tr('addColour'),
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
