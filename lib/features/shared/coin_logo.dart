import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/logo_provider.dart';

class CoinLogo extends StatelessWidget {
  final String base; // BTC/ETH/...
  final double size;
  final double radius;
  final EdgeInsets padding;

  const CoinLogo({
    super.key,
    required this.base,
    this.size = 28,
    this.radius = 6,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final asset = localLogoAsset(base);

    Widget child;
    if (asset != null && asset.endsWith('.svg')) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _fallbackAvatar(context),
        ),
      );
    } else if (asset != null && asset.endsWith('.png')) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          asset, 
          width: size, 
          height: size, 
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(context),
        ),
      );
    } else {
      // Dùng CDN PNG có cache
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: remotePngUrl(base),
          width: size, height: size, fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          errorWidget: (_, __, ___) => _fallbackAvatar(context),
          placeholder: (_, __) => _placeholder(context),
        ),
      );
    }

    return Padding(padding: padding, child: child);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }

  Widget _fallbackAvatar(BuildContext context) {
    final text = (normalizeSymbol(base).toUpperCase());
    final label = text.length > 4 ? text.substring(0, 4) : text;
    
    // Tạo màu dựa trên hash của symbol để consistent
    final hash = text.hashCode;
    final hue = (hash % 360).toDouble();
    final color = HSVColor.fromAHSV(1.0, hue, 0.6, 0.8).toColor();
    
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(label,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
