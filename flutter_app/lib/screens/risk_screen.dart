import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';
import 'package:omnix_hub/widgets/risk_indicator.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RustBridge>(
      builder: (context, bridge, _) {
        final assessments = bridge.riskAssessments;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Risk Assessment'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => bridge.refreshRisk(),
              ),
            ],
          ),
          body: assessments.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildOverallRisk(context, assessments),
                    const SizedBox(height: 16),
                    ...assessments
                        .map((a) => _buildAssessmentCard(context, a)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speed,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          const SizedBox(height: 16),
          Text('No risk assessments yet',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Run a scan to generate risk data',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOverallRisk(
      BuildContext context, List<RiskAssessmentItem> assessments) {
    final avgScore = assessments.isEmpty
        ? 0.0
        : assessments.map((a) => a.totalScore).reduce((a, b) => a + b) /
            assessments.length;
    final maxScore = assessments.isEmpty
        ? 0.0
        : assessments
            .map((a) => a.totalScore)
            .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('System Risk Overview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RiskIndicator(
                  score: avgScore,
                  label: 'Average',
                  size: 100,
                ),
                RiskIndicator(
                  score: maxScore,
                  label: 'Highest',
                  size: 100,
                ),
                Column(
                  children: [
                    Text('${assessments.length}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Files Assessed',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(
      BuildContext context, RiskAssessmentItem assessment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: RiskIndicator(
          score: assessment.totalScore,
          label: '',
          size: 44,
          showLabel: false,
        ),
        title: Text(
          assessment.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${assessment.level} - Score: ${assessment.totalScore.toStringAsFixed(1)}/10',
          style: TextStyle(
            color: _levelColor(assessment.level),
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Risk Factors:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...assessment.factors.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              value: (f.contribution / 4.0).clamp(0.0, 1.0),
                              color: _factorColor(f.contribution),
                              backgroundColor: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13)),
                                Text(f.explanation,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            '+${f.contribution.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _factorColor(f.contribution),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.deepOrange;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  Color _factorColor(double contribution) {
    if (contribution >= 3.0) return Colors.red;
    if (contribution >= 1.5) return Colors.orange;
    if (contribution >= 0.5) return Colors.amber;
    return Colors.green;
  }
}
