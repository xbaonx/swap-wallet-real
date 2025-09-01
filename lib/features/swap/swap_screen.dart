import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../data/polling_service.dart';
import '../../domain/logic/portfolio_engine.dart';
import '../../domain/models/coin.dart';
import '../../domain/models/portfolio.dart';
import '../../storage/prefs_store.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/widgets/empty_state.dart';
import 'widgets/search_bar.dart';
import 'widgets/top_coin_item.dart';

class SwapScreen extends StatefulWidget {
  final PrefsStore prefsStore;
  final PollingService pollingService;
  final PortfolioEngine portfolioEngine;

  const SwapScreen({
    super.key,
    required this.prefsStore,
    required this.pollingService,
    required this.portfolioEngine,
  });

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Coin> _coins = [];
  List<Coin> _filteredCoins = [];
  late Portfolio _portfolio;
  String _searchQuery = '';
  SortType _sortType = SortType.volume;
  StreamSubscription<List<Coin>>? _coinsSub;
  StreamSubscription<Portfolio>? _portfolioSub;
  VoidCallback? _prefsListener;


  @override
  void initState() {
    super.initState();
    // Initialize với portfolio thật từ prefsStore/engine
    _portfolio = widget.portfolioEngine.currentPortfolio;
    
    _setupStreams();
  }

  void _setupStreams() {
    _coinsSub = widget.pollingService.coinsStream.listen((coins) {
      if (!mounted) return;
      setState(() {
        // Use only real API data from Binance
        _coins = coins;
        _filterAndSort();
      });
    });

    _portfolioSub = widget.portfolioEngine.portfolioStream.listen((portfolio) {
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
      });
    });

    _prefsListener = () {
      if (!mounted) return;
      setState(() {
        _portfolio = widget.prefsStore.portfolio.value;
      });
    };
    widget.prefsStore.portfolio.addListener(_prefsListener!);
  }

  void _filterAndSort() {
    // Get all coins with valid prices (since quoteVolume is 0 from 1inch API)
    final validCoins = _coins.where((coin) {
      // Check if this coin has a valid price
      return coin.last > 0;
    }).toList();

    _filteredCoins = validCoins.where((coin) {
      if (_searchQuery.isEmpty) return true;
      return coin.base.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortType) {
      case SortType.volume:
        // Sort by 24h quote volume (descending)
        _filteredCoins.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
        break;
      case SortType.percent24h:
        _filteredCoins.sort((a, b) => b.pct24h.compareTo(a.pct24h));
        break;
      case SortType.alphabetical:
        _filteredCoins.sort((a, b) => a.base.compareTo(b.base));
        break;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterAndSort();
    });
  }

  void _onSortChanged(SortType sortType) {
    setState(() {
      _sortType = sortType;
      _filterAndSort();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.tr(context, 'swap.title')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (widget.pollingService.isOffline) const OfflineBanner(),
          CryptoSearchBar(
            controller: _searchController,
            onSearchChanged: _onSearchChanged,
            sortType: _sortType,
            onSortChanged: _onSortChanged,
            onRefresh: widget.pollingService.refreshRanking,
          ),
          Expanded(
            child: _filteredCoins.isEmpty
                ? EmptyState(
                    message: AppI18n.tr(context, 'swap.empty'),
                    icon: Icons.search_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredCoins.length,
                    itemBuilder: (context, index) {
                      final coin = _filteredCoins[index];
                      final position = _portfolio.positions[coin.base];
                      
                      return TopCoinItem(
                        coin: coin,
                        position: position,
                        portfolio: _portfolio,
                        portfolioEngine: widget.portfolioEngine,
                        pollingService: widget.pollingService,
                        prefsStore: widget.prefsStore,
                        rank: index + 1,
                        isExpanded: false,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _coinsSub?.cancel();
    _portfolioSub?.cancel();
    if (_prefsListener != null) {
      widget.prefsStore.portfolio.removeListener(_prefsListener!);
    }
    _searchController.dispose();
    super.dispose();
  }
}

enum SortType { volume, percent24h, alphabetical }
