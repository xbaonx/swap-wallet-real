import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize với portfolio thật từ prefsStore/engine
    _portfolio = widget.portfolioEngine.currentPortfolio;
    _setupStreams();
  }

  void _setupStreams() {
    widget.pollingService.coinsStream.listen((coins) {
      setState(() {
        _coins = coins;
        _filterAndSort();
      });
    });

    widget.portfolioEngine.portfolioStream.listen((portfolio) {
      setState(() {
        _portfolio = portfolio;
      });
    });

    widget.prefsStore.portfolio.addListener(() {
      setState(() {
        _portfolio = widget.prefsStore.portfolio.value;
      });
    });
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
        // Sort by price instead since quoteVolume is 0 for 1inch API data
        _filteredCoins.sort((a, b) => b.last.compareTo(a.last));
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
        title: const Text('Swap'),
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
                ? const EmptyState(
                    message: 'No coins found',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum SortType { volume, percent24h, alphabetical }
