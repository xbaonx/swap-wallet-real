import 'package:flutter/material.dart';
import '../../data/polling_service.dart';
import '../../domain/logic/portfolio_engine.dart';
import '../../domain/models/coin.dart';
import '../../domain/models/portfolio.dart';
import '../../storage/prefs_store.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/widgets/empty_state.dart';
import '../overview/widgets/summary_header.dart';
import '../overview/widgets/metrics_strip.dart';
import 'widgets/holding_item.dart';

class PortfolioScreen extends StatefulWidget {
  final PrefsStore prefsStore;
  final PollingService pollingService;
  final PortfolioEngine portfolioEngine;

  const PortfolioScreen({
    super.key,
    required this.prefsStore,
    required this.pollingService,
    required this.portfolioEngine,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Coin> _coins = [];
  late Portfolio _portfolio;

  @override
  void initState() {
    super.initState();
    // Initialize với portfolio thật từ prefsStore/engine
    _portfolio = widget.portfolioEngine.currentPortfolio;
    print('🔍 PORTFOLIO SCREEN DEBUG: Initial portfolio USDT: ${_portfolio.usdt}');
    print('🔍 PORTFOLIO SCREEN DEBUG: Initial positions: ${_portfolio.positions.keys}');
    _setupStreams();
  }

  void _setupStreams() {
    widget.pollingService.coinsStream.listen((coins) {
      setState(() {
        _coins = coins;
      });
      _updateWatchedPositions();
    });

    widget.portfolioEngine.portfolioStream.listen((portfolio) {
      print('🔍 PORTFOLIO SCREEN: Engine stream update - USDT: ${portfolio.usdt}');
      setState(() {
        _portfolio = portfolio;
      });
      _updateWatchedPositions();
    });

    widget.prefsStore.portfolio.addListener(() {
      final newPortfolio = widget.prefsStore.portfolio.value;
      print('🔍 PORTFOLIO SCREEN: PrefsStore listener - USDT: ${newPortfolio.usdt}');
      setState(() {
        _portfolio = newPortfolio;
      });
      _updateWatchedPositions();
    });
  }

  void _updateWatchedPositions() {
    final positionBases = _portfolio.positions.keys.where((base) {
      return _portfolio.positions[base]?.qty != null && 
             _portfolio.positions[base]!.qty > 0;
    }).toSet();
    widget.pollingService.updateWatchedPositions(positionBases);
  }


  Map<String, double> get _currentPrices {
    final prices = {for (var coin in _coins) coin.base: coin.last};
    
    // Price mapping completed
    
    return prices;
  }

  List<MapEntry<String, dynamic>> get _holdingsList {
    final holdings = <MapEntry<String, dynamic>>[];
    
    for (final entry in _portfolio.positions.entries) {
      final base = entry.key;
      final position = entry.value;
      
      if (position.qty > 1e-8) {
        final coin = _coins.firstWhere(
          (c) => c.base == base,
          orElse: () => Coin(
            symbolPair: '${base}USDT',
            base: base,
            last: 0.0,
            bid: 0.0,
            ask: 0.0,
            pct24h: 0.0,
            quoteVolume: 0.0,
          ),
        );
        
        final value = position.qty * coin.last;
        holdings.add(MapEntry(base, {
          'coin': coin,
          'position': position,
          'value': value,
        }));
      }
    }
    
    // Sort by value descending
    holdings.sort((a, b) => b.value['value'].compareTo(a.value['value']));
    return holdings;
  }

  @override
  Widget build(BuildContext context) {
    final holdings = _holdingsList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (widget.pollingService.isOffline) const OfflineBanner(),
          SummaryHeader(
            portfolio: _portfolio,
            currentPrices: _currentPrices,
            prefsStore: widget.prefsStore,
            portfolioEngine: widget.portfolioEngine,
          ),
          MetricsStrip(
            portfolio: _portfolio,
            currentPrices: _currentPrices,
          ),
          Expanded(
            child: holdings.isEmpty
                ? const EmptyState(
                    message: 'Chưa có coin — vào tab Swap để mua',
                    icon: Icons.account_balance_wallet_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: holdings.length,
                    itemBuilder: (context, index) {
                      final entry = holdings[index];
                      final base = entry.key;
                      final data = entry.value;
                      
                      return HoldingItem(
                        coin: data['coin'],
                        position: data['position'],
                        portfolioEngine: widget.portfolioEngine,
                        prefsStore: widget.prefsStore,
                        isExpanded: false,
                        onTap: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
