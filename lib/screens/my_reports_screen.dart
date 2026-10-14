import 'package:flutter/material.dart';
import '../models/accessibility_report.dart';
import '../services/report_moderation_service.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});
  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}
class _MyReportsScreenState extends State<MyReportsScreen> {
  final _service = ReportModerationService();
  Stream<List<AccessibilityReport>>? _reports;
  @override
  void initState() {
    super.initState();
    if (_service.currentUser != null) _reports = _service.watchMyReports();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Reports')),
    body: _reports == null ? const Center(child: Text('Sign in to view your reports.')) :
      StreamBuilder<List<AccessibilityReport>>(
        stream: _reports,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Reports could not be loaded. Check your connection and try again.'),
              TextButton(onPressed: () => setState(() => _reports = _service.watchMyReports()), child: const Text('Retry')),
            ]),
          ));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final reports = snapshot.data!;
          if (reports.isEmpty) return const Center(child: Text('You have not submitted any reports yet.'));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: reports.length,
            itemBuilder: (context, i) {
              final report = reports[i];
              return Card(child: ListTile(
                title: Text(report.placeName),
                subtitle: Text('${report.targetField}\n${report.status.toUpperCase()}'),
                isThreeLine: true, trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
                  title: Text(report.placeName),
                  content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Status: ${report.status}'),
                    Text('Reported information: ${report.targetField}'),
                    const SizedBox(height: 12), Text(report.description),
                    if (report.createdAt != null) Text('Submitted: ${report.createdAt!.toLocal()}'),
                    if (report.adminNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 12), Text('Staff response: ${report.adminNotes}'),
                    ],
                  ])),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                )),
              ));
            },
          );
        },
      ),
  );
}
