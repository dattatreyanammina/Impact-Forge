import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'cache_aware_http_client.dart';

enum PriceTrend { up, down, stable }

class MarketPrice {
  final String market;
  final String commodity;
  final String variety;
  final double pricePerKg;
  final double pricePerQuintal;
  final double maxPrice;
  final double minPrice;
  final double prevPrice;
  final String lastArrival;
  final String sourceUrl;

  const MarketPrice({
    required this.market,
    required this.commodity,
    required this.variety,
    required this.pricePerKg,
    required this.pricePerQuintal,
    required this.maxPrice,
    required this.minPrice,
    required this.prevPrice,
    required this.lastArrival,
    required this.sourceUrl,
  });

  String get displayName => variety.isEmpty ? commodity : '$commodity - $variety';
  String get crop => commodity;
  String get mandi => market;
  String get formattedPrice => 'Rs ${pricePerQuintal.toStringAsFixed(0)}/q';
  String get emoji => _emojiForCommodity(commodity);

  PriceTrend get trend {
    if (prevPrice == 0 || pricePerQuintal == prevPrice) {
      return PriceTrend.stable;
    }
    return pricePerQuintal > prevPrice ? PriceTrend.up : PriceTrend.down;
  }

  double get changePercent {
    if (prevPrice == 0) return 0;
    return ((pricePerQuintal - prevPrice) / prevPrice) * 100;
  }
}

typedef CropPrice = MarketPrice;

class MarketSearchResult {
  final List<MarketPrice> prices;
  final bool exactMatch;
  final String message;

  const MarketSearchResult({
    required this.prices,
    required this.exactMatch,
    required this.message,
  });
}

final marketSearchProvider =
    FutureProvider.family<MarketSearchResult, String>((ref, query) async {
  return MarketService.instance.search(query);
});

final marketProvider = marketPreviewProvider;

final marketPreviewProvider = FutureProvider<List<MarketPrice>>((ref) async {
  return MarketService.instance.preview();
});

class MarketService {
  MarketService._();

  static final MarketService instance = MarketService._();

  static const _producePages = <String>[
    'https://www.commoditymarketlive.com/mandi-price',
    'https://www.commoditymarketlive.com/mandi-price-market/fruit-market',
  ];

  List<MarketPrice>? _cachedPrices;
  DateTime? _cachedAt;

  Future<MarketSearchResult> search(String query) async {
    final normalized = query.trim().toLowerCase();
    final allPrices = await _loadProducePrices();

    if (allPrices.isEmpty) {
      return const MarketSearchResult(
        prices: [],
        exactMatch: false,
        message: 'No live fruit or vegetable prices could be loaded right now.',
      );
    }

    if (normalized.isEmpty) {
      return MarketSearchResult(
        prices: allPrices.take(24).toList(),
        exactMatch: false,
        message: 'Showing the latest live fruit and vegetable prices.',
      );
    }

    final filtered = allPrices.where((price) {
      final text = '${price.market} ${price.commodity} ${price.variety}'.toLowerCase();
      return text.contains(normalized) || _produceAliases(normalized).any(text.contains);
    }).toList();
    filtered.sort(_sortPrices);

    if (filtered.isNotEmpty) {
      return MarketSearchResult(
        prices: filtered,
        exactMatch: true,
        message: 'Found live fruit and vegetable prices for "$query".',
      );
    }

    return MarketSearchResult(
      prices: allPrices.take(24).toList(),
      exactMatch: false,
      message: 'No exact match for "$query" yet. Showing live fruit and vegetable prices instead.',
    );
  }

  Future<List<MarketPrice>> preview() async {
    final cached = _cachedPrices;
    if (cached != null && cached.isNotEmpty) {
      return cached.take(8).toList();
    }

    final loaded = await _loadProducePrices();
    if (loaded.isNotEmpty) {
      return loaded.take(8).toList();
    }

    return const [
      MarketPrice(
        market: 'Live Produce',
        commodity: 'Apple',
        variety: 'Preview',
        pricePerKg: 0,
        pricePerQuintal: 0,
        maxPrice: 0,
        minPrice: 0,
        prevPrice: 0,
        lastArrival: 'Live on Market page',
        sourceUrl: 'https://www.commoditymarketlive.com/mandi-price',
      ),
    ];
  }

  Future<List<MarketPrice>> _loadProducePrices() async {
    final cacheAge = _cachedAt == null ? null : DateTime.now().difference(_cachedAt!);
    if (_cachedPrices != null && cacheAge != null && cacheAge.inMinutes < 15) {
      return _cachedPrices!;
    }

    final results = <MarketPrice>[];
    for (final pageUrl in _producePages) {
      final response = await _get(Uri.parse(pageUrl));
      if (response.statusCode != 200) continue;
      results.addAll(_parseMarkdownTable(response.body, pageUrl));
    }

    if (results.isNotEmpty) {
      results.sort(_sortPrices);
      _cachedPrices = results;
      _cachedAt = DateTime.now();
    }

    return results;
  }

  Future<http.Response> _get(Uri url) {
    final effectiveUrl = kIsWeb
        ? Uri.parse('https://r.jina.ai/${url.toString()}')
        : url;
    final client = CacheAwareHttpClient();
    return client.get(effectiveUrl);
  }
}

List<MarketPrice> _parseMarkdownTable(String body, String sourceUrl) {
  final parsed = <MarketPrice>[];
  final lines = body.split(RegExp(r'\r?\n'));
  var priceDate = '';

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || !line.contains('|')) continue;

    final dateMatch = RegExp(r'Price Date:\s*\|\s*([0-9]{4}-[0-9]{2}-[0-9]{2})').firstMatch(line);
    if (dateMatch != null) {
      priceDate = dateMatch.group(1)!;
      continue;
    }

    final parts = line
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) continue;
    final first = parts.first.toLowerCase();
    if (first == 'commodity' || first == 'market' || first.startsWith('---')) continue;

    if (parts.length == 7) {
      final commodityText = parts[0];
      final priceKg = parseCurrency(parts[1]);
      final priceQ = parseCurrency(parts[2]);
      final maxPrice = parseCurrency(parts[3]);
      final minPrice = parseCurrency(parts[4]);
      final prevPrice = parseCurrency(parts[5]);
      final lastArrival = parts[6];
      _addParsedPrice(
        parsed,
        sourceUrl: sourceUrl,
        market: 'Live Produce',
        commodityText: commodityText,
        pricePerKg: priceKg,
        pricePerQuintal: priceQ,
        maxPrice: maxPrice,
        minPrice: minPrice,
        prevPrice: prevPrice,
        lastArrival: lastArrival.isEmpty ? priceDate : lastArrival,
      );
      continue;
    }

    if (parts.length >= 8) {
      final commodityText = parts[0];
      final market = parts[1];
      final priceKg = parseCurrency(parts[2]);
      final priceQ = parseCurrency(parts[3]);
      final maxPrice = parseCurrency(parts[4]);
      final minPrice = parseCurrency(parts[5]);
      final prevPrice = parseCurrency(parts[6]);
      final lastArrival = parts[7];
      _addParsedPrice(
        parsed,
        sourceUrl: sourceUrl,
        market: market,
        commodityText: commodityText,
        pricePerKg: priceKg,
        pricePerQuintal: priceQ,
        maxPrice: maxPrice,
        minPrice: minPrice,
        prevPrice: prevPrice,
        lastArrival: lastArrival.isEmpty ? priceDate : lastArrival,
      );
    }
  }

  return parsed;
}

void _addParsedPrice(
  List<MarketPrice> parsed, {
  required String sourceUrl,
  required String market,
  required String commodityText,
  required double pricePerKg,
  required double pricePerQuintal,
  required double maxPrice,
  required double minPrice,
  required double prevPrice,
  required String lastArrival,
}) {
  final cleanedCommodityText = _stripMarkdownLinkText(commodityText);
  final split = cleanedCommodityText.split(' - ');
  final commodity = split.first.trim();
  final variety = split.length > 1 ? split.sublist(1).join(' - ').trim() : '';

  parsed.add(
    MarketPrice(
      market: market,
      commodity: commodity,
      variety: variety,
      pricePerKg: pricePerKg,
      pricePerQuintal: pricePerQuintal,
      maxPrice: maxPrice,
      minPrice: minPrice,
      prevPrice: prevPrice,
      lastArrival: lastArrival.isEmpty ? 'Live' : lastArrival,
      sourceUrl: sourceUrl,
    ),
  );
}

String _stripMarkdownLinkText(String value) {
  final markdownMatch = RegExp(r'^\[(.+)\]\((.+)\)$').firstMatch(value.trim());
  if (markdownMatch != null) {
    return markdownMatch.group(1)!.trim();
  }

  return value.trim();
}

List<String> _produceAliases(String query) {
  const map = <String, List<String>>{
    'apple': ['apple'],
    'banana': ['banana'],
    'mango': ['mango'],
    'orange': ['orange'],
    'grapes': ['grapes'],
    'guava': ['guava'],
    'papaya': ['papaya'],
    'watermelon': ['watermelon'],
    'muskmelon': ['muskmelon'],
    'tomato': ['tomato'],
    'onion': ['onion'],
    'potato': ['potato'],
    'carrot': ['carrot'],
    'cabbage': ['cabbage'],
    'cauliflower': ['cauliflower'],
    'lemon': ['lemon', 'lime'],
    'lime': ['lemon', 'lime'],
    'chilli': ['chilli', 'chili'],
    'chili': ['chilli', 'chili'],
  };

  for (final entry in map.entries) {
    if (query.contains(entry.key)) {
      return entry.value;
    }
  }
  return const [];
}

double parseCurrency(String value) {
  final match = RegExp(r'[\d,]+(?:\.\d+)?').firstMatch(value);
  if (match == null) return 0;
  return double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
}

int _sortPrices(MarketPrice a, MarketPrice b) {
  final arrival = b.lastArrival.compareTo(a.lastArrival);
  if (arrival != 0) return arrival;
  return a.market.compareTo(b.market);
}

String _emojiForCommodity(String commodity) {
  final key = commodity.toLowerCase();
  if (key.contains('apple')) return '🍎';
  if (key.contains('banana')) return '🍌';
  if (key.contains('mango')) return '🥭';
  if (key.contains('orange') || key.contains('lemon') || key.contains('lime')) return '🍊';
  if (key.contains('grapes')) return '🍇';
  if (key.contains('tomato')) return '🍅';
  if (key.contains('onion')) return '🧅';
  if (key.contains('potato')) return '🥔';
  if (key.contains('carrot')) return '🥕';
  if (key.contains('cabbage') || key.contains('cauliflower')) return '🥬';
  if (key.contains('chilli') || key.contains('chili')) return '🌶️';
  return '🪴';
}
