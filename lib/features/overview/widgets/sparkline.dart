import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/colors.dart';
import '../../../data/polling_service.dart';
import '../../../domain/models/coin.dart';

class SparklineWidget extends StatefulWidget {
  final Coin coin;
  final PollingService pollingService;

  const SparklineWidget({
    super.key,
    required this.coin,
    required this.pollingService,
  });

  @override
  State<SparklineWidget> createState() => _SparklineWidgetState();
}

class _SparklineWidgetState extends State<SparklineWidget> {
  List<double> _priceData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSparklineData();
  }

  @override
  void didUpdateWidget(SparklineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coin.symbolPair != widget.coin.symbolPair) {
      _loadSparklineData();
    }
  }

  Future<void> _loadSparklineData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.pollingService.getSparklineData(widget.coin.symbolPair);
      if (mounted) {
        setState(() {
          _priceData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SparklineSkeleton();
    }

    if (_priceData.isEmpty) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          'No data',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final isPositive = widget.coin.pct24h >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    
    final spots = _priceData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    final minY = _priceData.reduce((a, b) => a < b ? a : b);
    final maxY = _priceData.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (_priceData.length - 1).toDouble(),
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.24),
                  color.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _SparklineSkeleton extends StatelessWidget {
  const _SparklineSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}
