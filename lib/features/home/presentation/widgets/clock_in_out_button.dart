import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClockInOutButton extends StatelessWidget {
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const ClockInOutButton({
    super.key,
    required this.clockInTime,
    required this.clockOutTime,
    required this.onClockIn,
    required this.onClockOut,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isClockedIn = clockInTime != null && clockOutTime == null;
    final now = DateTime.now();
    Duration? duration;

    if (isClockedIn) {
      duration = now.difference(clockInTime!);
    } else if (clockInTime != null && clockOutTime != null) {
      duration = clockOutTime!.difference(clockInTime!);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (duration != null)
            Text(
              _formatDuration(duration),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isClockedIn ? onClockOut : onClockIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: isClockedIn ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text(
              isClockedIn ? 'Clock Out' : 'Clock In',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          if (clockInTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Clocked in at: ${DateFormat('HH:mm:ss').format(clockInTime!)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          if (clockOutTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Clocked out at: ${DateFormat('HH:mm:ss').format(clockOutTime!)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
        ],
      ),
    );
  }
}
