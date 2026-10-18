import 'package:flutter/material.dart';

/// Indikator "kamera aktif" yang selalu terlihat saat kamera menyala (SRS PRV-03).
class CameraActiveBadge extends StatelessWidget {
  const CameraActiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          SizedBox(width: 6),
          Text('Kamera aktif', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Label kecil pengganti [CameraActiveBadge] saat kamera asli tidak menyala
/// dan CV Engine memakai frame simulasi.
class SimulationModeBadge extends StatelessWidget {
  const SimulationModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text('Mode simulasi', style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
