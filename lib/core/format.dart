import 'package:intl/intl.dart';

class AppFormat {
  static final _usdtFormatter = NumberFormat('#,##0.00', 'en_US');
  static final _coinFormatter = NumberFormat('#,##0.000000', 'en_US');
  static final _percentFormatter = NumberFormat('+#,##0.00%;-#,##0.00%', 'en_US');
  static final _volumeFormatter = NumberFormat.compact(locale: 'en_US');

  static String formatUsdt(double value) {
    return _usdtFormatter.format(value);
  }

  static String formatCoin(double value) {
    return _coinFormatter.format(value);
  }

  static String formatPercent(double value) {
    return _percentFormatter.format(value / 100);
  }

  static String formatVolume(double value) {
    if (value >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(1)}B';
    } else if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(1)}M';
    } else if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(1)}K';
    }
    return _volumeFormatter.format(value);
  }

  static String formatLargeNumber(double value) {
    return _volumeFormatter.format(value);
  }
}
