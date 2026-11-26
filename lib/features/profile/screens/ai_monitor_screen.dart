import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/monitor/ai_model_registry.dart';
import '../../../core/ai/monitor/ai_monitor_models.dart';
import '../../../core/ai/monitor/ai_telemetry_service.dart';
import '../../../shared/widgets/true_me_ui.dart';

class AiMonitorScreen extends StatefulWidget {
  const AiMonitorScreen({super.key});

  @override
  State<AiMonitorScreen> createState() => _AiMonitorScreenState();
}

class _AiMonitorScreenState extends State<AiMonitorScreen> {
  MonitorDateRange _dateRange = MonitorDateRange.last7Days;
  String _providerFilter = 'all';
  String _featureFilter = 'all';
  bool _isRefreshing = false;
  bool _isLoading = true;

  List<MonitoredModelState> _models = [];
  List<AiRequestRecord> _records = [];
  Map<String, ProviderSnapshot> _snapshots = {};
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadData(refreshOfficial: true);
  }

  Future<void> _loadData({bool refreshOfficial = false}) async {
    if (refreshOfficial && mounted) setState(() => _isRefreshing = true);

    if (refreshOfficial) {
      await AiTelemetryService.refreshOfficialQuotas();
    }

    final states = await AiTelemetryService.buildModelStates(
      range: _dateRange,
      providerFilter: _providerFilter,
      featureFilter: _featureFilter,
    );
    final recs = await AiTelemetryService.getRecords(
      range: _dateRange,
      providerFilter: _providerFilter,
      featureFilter: _featureFilter,
    );
    final snaps = AiTelemetryService.cachedSnapshots;

    if (!mounted) return;
    setState(() {
      _models = states;
      _records = recs;
      _snapshots = snaps;
      _lastSync = snaps.values.isNotEmpty
          ? snaps.values.map((s) => s.fetchedAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now();
      _isRefreshing = false;
      _isLoading = false;
    });
  }

  String _formatCount(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.round().toString();
  }

  String _formatLocalTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
  }

  Color _badgeBg(DataSourceBadge badge, bool isDark) {
    switch (badge) {
      case DataSourceBadge.official:
        return isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen;
      case DataSourceBadge.internallyTracked:
        return isDark ? AppColors.darkAccentWash : AppColors.accentWash;
      case DataSourceBadge.estimated:
        return isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber;
      case DataSourceBadge.unavailable:
        return isDark ? const Color(0xFF2D161A) : const Color(0xFFFDECEC);
    }
  }

  Color _badgeFg(DataSourceBadge badge, bool isDark) {
    switch (badge) {
      case DataSourceBadge.official:
        return AppColors.success;
      case DataSourceBadge.internallyTracked:
        return isDark ? AppColors.darkAccent : AppColors.accent;
      case DataSourceBadge.estimated:
        return isDark ? AppColors.darkWarning : AppColors.pastelAmberInk;
      case DataSourceBadge.unavailable:
        return AppColors.error;
    }
  }

  Widget _sourceBadge(DataSourceBadge badge, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeBg(badge, isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: _badgeFg(badge, isDark),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalRequests = _records.length;
    final totalTokens = _records.fold<int>(0, (s, r) => s + r.totalTokens);
    final totalCost = _records.fold<double>(
      0.0,
      (s, r) => s + (r.providerCostUsd ?? r.calculatedCostUsd),
    );
    final activeCount = _models.where((m) => m.model.isActive).length;

    final allFeatures = <String>{
      'all',
      ..._models.expand((m) => m.model.assignedFeatures),
    }.toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('AI Model & Quota Monitor'),
        actions: [
          IconButton(
            tooltip: 'Sync Official Provider Quotas',
            onPressed: _isRefreshing ? null : () => _loadData(refreshOfficial: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(refreshOfficial: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // Sync status banner
                  TrueMeCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 18, color: context.accentColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Official Provider APIs first · Internal tracking fallback · Synced ${_formatLocalTime(_lastSync)}',
                            style: AppTypography.bodySmall.copyWith(color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Overview KPI Row
                  Row(
                    children: [
                      Expanded(
                        child: _KpiTile(
                          label: 'Discovered Models',
                          value: '$activeCount / ${_models.length}',
                          icon: Icons.hub_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _KpiTile(
                          label: 'Requests (${_dateRange.label})',
                          value: _formatCount(totalRequests),
                          icon: Icons.bolt_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiTile(
                          label: 'Total Tokens',
                          value: _formatCount(totalTokens),
                          icon: Icons.data_usage_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _KpiTile(
                          label: 'Est. Cost (USD)',
                          value: '\$${totalCost.toStringAsFixed(4)}',
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Official Provider Status Cards
                  Text('Official Provider Status', style: AppTypography.sectionHeading),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AiModelRegistry.knownProviders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final p = AiModelRegistry.knownProviders[i];
                        final snap = _snapshots[p];
                        final status = snap?.status ?? DataSourceBadge.unavailable;
                        return SizedBox(
                          width: 215,
                          child: TrueMeCard(
                            borderRadius: 16,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AiModelRegistry.providerDisplayName(p),
                                      style: AppTypography.cardTitle.copyWith(fontSize: 13.5),
                                    ),
                                    _sourceBadge(status, isDark),
                                  ],
                                ),
                                if (p == 'openrouter' && snap?.officialCreditLimit != null)
                                  Text(
                                    'Credits: \$${(snap!.officialCreditRemaining ?? 0).toStringAsFixed(2)} / \$${snap.officialCreditLimit!.toStringAsFixed(2)} left',
                                    style: AppTypography.bodySmall.copyWith(color: context.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (snap != null && snap.discoveredModelIds.isNotEmpty)
                                  Text(
                                    '${snap.discoveredModelIds.length} active models verified',
                                    style: AppTypography.bodySmall.copyWith(color: context.textPrimary),
                                  )
                                else
                                  Text(
                                    snap?.errorDetail ?? 'Tap sync to query official API',
                                    style: AppTypography.bodySmall.copyWith(color: context.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  'Updated: ${_formatLocalTime(snap?.fetchedAt)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 10.5,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Date Range & Provider Filters
                  Text('Filters & Analytics', style: AppTypography.sectionHeading),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: MonitorDateRange.values.map((r) {
                        final selected = _dateRange == r;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(r.label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _dateRange = r);
                              _loadData();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', ...AiModelRegistry.knownProviders].map((p) {
                        final selected = _providerFilter == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(p == 'all' ? 'All Providers' : AiModelRegistry.providerDisplayName(p)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _providerFilter = p);
                              _loadData();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (allFeatures.length > 1) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: allFeatures.contains(_featureFilter) ? _featureFilter : 'all',
                      decoration: InputDecoration(
                        labelText: 'Filter by Application Feature',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: allFeatures
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f == 'all' ? 'All Application Features' : f),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _featureFilter = val);
                        _loadData();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Historical Daily Token Chart
                  _DailyTokenChartCard(records: _records),
                  const SizedBox(height: 18),

                  // Per-Model Expandable Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Configured Models (${_models.length})',
                        style: AppTypography.sectionHeading,
                      ),
                      Text(
                        'Tap to expand',
                        style: AppTypography.bodySmall.copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._models.map((state) => _buildModelCard(state, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildModelCard(MonitoredModelState state, bool isDark) {
    final m = state.model;
    final primary = state.primaryQuota;
    final pct = primary?.percentage ?? primary?.percentageMax ?? 0.0;
    final progressValue = (pct / 100.0).clamp(0.0, 1.0);

    String quotaSummary;
    if (primary == null) {
      quotaSummary = '${_formatCount(state.totalTokens)} tokens tracked (quota unavailable)';
    } else if (primary.isRangeEstimate) {
      quotaSummary =
          'Used ${primary.used.toStringAsFixed(0)} of ~${primary.totalMin!.toStringAsFixed(0)}–${primary.totalMax!.toStringAsFixed(0)} ${primary.unit} '
          '(~${primary.percentageMin!.toStringAsFixed(1)}–${primary.percentageMax!.toStringAsFixed(1)}%)';
    } else if (primary.total != null) {
      final rem = primary.remaining ?? math.max(0.0, primary.total! - primary.used);
      quotaSummary =
          'Used ${primary.used.toStringAsFixed(primary.unit == 'USD' ? 2 : 0)} / ${primary.total!.toStringAsFixed(primary.unit == 'USD' ? 2 : 0)} ${primary.unit} '
          '(${rem.toStringAsFixed(primary.unit == 'USD' ? 2 : 0)} left · ${pct.toStringAsFixed(1)}%)';
    } else {
      quotaSummary = 'Tracked: ${_formatCount(primary.used)} ${primary.unit}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TrueMeCard(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    m.displayName,
                    style: AppTypography.cardTitle.copyWith(fontSize: 14.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (primary != null) _sourceBadge(primary.source, isDark),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  '${AiModelRegistry.providerDisplayName(m.provider)} · ${m.modelId}',
                  style: AppTypography.bodySmall.copyWith(color: context.textSecondary, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: primary?.total != null || primary?.isRangeEstimate == true ? progressValue : 0.0,
                    minHeight: 7,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 85
                          ? AppColors.error
                          : (pct >= 60 ? AppColors.warning : context.accentColor),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  quotaSummary,
                  style: AppTypography.bodySmall.copyWith(fontSize: 11.5, color: context.textPrimary),
                ),
              ],
            ),
            children: [
              Divider(height: 14, color: context.borderColor),
              _kvRow('Provider', AiModelRegistry.providerDisplayName(m.provider)),
              _kvRow('Model ID', m.modelId),
              _kvRow('Status', m.isActive ? (m.isPrimary ? 'Active (Primary)' : 'Active (Fallback)') : 'Inactive'),
              _kvRow('Total Requests', '${state.totalRequests} (${state.failedRequests} failed)'),
              _kvRow('Input Tokens', _formatCount(state.inputTokens)),
              _kvRow('Output Tokens', _formatCount(state.outputTokens)),
              _kvRow('Total Tokens', _formatCount(state.totalTokens)),
              _kvRow(
                'Estimated Cost',
                '\$${state.estimatedCostUsd.toStringAsFixed(5)} (${state.costSource.label})',
              ),
              _kvRow(
                'Reset Schedule',
                primary?.nextResetAt != null
                    ? '${primary!.resetSchedule.label} · ${_formatLocalTime(primary.nextResetAt)}'
                    : (primary?.resetSchedule.label ?? 'Unknown'),
              ),
              _kvRow('Last Updated', _formatLocalTime(state.lastUpdated)),
              if (m.assignedFeatures.isNotEmpty)
                _kvRow('Assigned Features', m.assignedFeatures.join(', ')),
              if (m.callbackRoutes.isNotEmpty)
                _kvRow('Callback Routes', m.callbackRoutes.join(', ')),
              if (state.discrepancyNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.discrepancyNote!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TrueMeCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(color: context.textSecondary, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.sectionHeading.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _DailyTokenChartCard extends StatelessWidget {
  final List<AiRequestRecord> records;

  const _DailyTokenChartCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final buckets = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      buckets['${d.month}/${d.day}'] = 0;
    }
    for (final r in records) {
      final local = r.timestamp.toLocal();
      final key = '${local.month}/${local.day}';
      if (buckets.containsKey(key)) {
        buckets[key] = (buckets[key] ?? 0) + r.totalTokens;
      }
    }
    final maxTok = buckets.values.fold<int>(1, (m, v) => v > m ? v : m);

    return TrueMeCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Token Consumption (7 Days)', style: AppTypography.cardTitle),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.entries.map((e) {
                final ratio = e.value / maxTok;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: math.max(0.06, ratio),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                color: e.value > 0
                                    ? context.accentColor
                                    : context.borderColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        e.key,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
