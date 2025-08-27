import 'package:json_annotation/json_annotation.dart';

part 'moralis_models.g.dart';

@JsonSerializable()
class MoralisTokenBalance {
  @JsonKey(name: 'token_address')
  final String tokenAddress;
  final String name;
  final String symbol;
  final String logo;
  final String thumbnail;
  final int decimals;
  final String balance;
  @JsonKey(name: 'possible_spam')
  final bool? possibleSpam;

  const MoralisTokenBalance({
    required this.tokenAddress,
    required this.name,
    required this.symbol,
    required this.logo,
    required this.thumbnail,
    required this.decimals,
    required this.balance,
    this.possibleSpam,
  });

  factory MoralisTokenBalance.fromJson(Map<String, dynamic> json) => _$MoralisTokenBalanceFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisTokenBalanceToJson(this);
}

@JsonSerializable()
class MoralisTokenBalancesResponse {
  final List<MoralisTokenBalance> result;
  final String? cursor;

  const MoralisTokenBalancesResponse({
    required this.result,
    this.cursor,
  });

  factory MoralisTokenBalancesResponse.fromJson(Map<String, dynamic> json) => _$MoralisTokenBalancesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisTokenBalancesResponseToJson(this);
}

@JsonSerializable()
class MoralisTokenTransfer {
  @JsonKey(name: 'transaction_hash')
  final String transactionHash;
  @JsonKey(name: 'log_index')
  final int logIndex;
  @JsonKey(name: 'from_address')
  final String fromAddress;
  @JsonKey(name: 'to_address')
  final String toAddress;
  final String value;
  @JsonKey(name: 'block_timestamp')
  final String blockTimestamp;
  @JsonKey(name: 'block_number')
  final String blockNumber;
  @JsonKey(name: 'block_hash')
  final String blockHash;
  @JsonKey(name: 'token_address')
  final String tokenAddress;
  final String? name;
  final String? symbol;
  final int? decimals;

  const MoralisTokenTransfer({
    required this.transactionHash,
    required this.logIndex,
    required this.fromAddress,
    required this.toAddress,
    required this.value,
    required this.blockTimestamp,
    required this.blockNumber,
    required this.blockHash,
    required this.tokenAddress,
    this.name,
    this.symbol,
    this.decimals,
  });

  factory MoralisTokenTransfer.fromJson(Map<String, dynamic> json) => _$MoralisTokenTransferFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisTokenTransferToJson(this);
}

@JsonSerializable()
class MoralisTokenTransfersResponse {
  final List<MoralisTokenTransfer> result;
  final String? cursor;

  const MoralisTokenTransfersResponse({
    required this.result,
    this.cursor,
  });

  factory MoralisTokenTransfersResponse.fromJson(Map<String, dynamic> json) => _$MoralisTokenTransfersResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisTokenTransfersResponseToJson(this);
}

@JsonSerializable()
class MoralisTokenPrice {
  @JsonKey(name: 'tokenName')
  final String tokenName;
  @JsonKey(name: 'tokenSymbol')
  final String tokenSymbol;
  @JsonKey(name: 'tokenLogo')
  final String? tokenLogo;
  @JsonKey(name: 'tokenDecimals')
  final String tokenDecimals;
  @JsonKey(name: 'nativePrice')
  final MoralisNativePrice nativePrice;
  @JsonKey(name: 'usdPrice')
  final double usdPrice;
  @JsonKey(name: 'exchangeAddress')
  final String? exchangeAddress;
  @JsonKey(name: 'exchangeName')
  final String? exchangeName;
  @JsonKey(name: '24hrPercentChange')
  final String? percent24h;

  const MoralisTokenPrice({
    required this.tokenName,
    required this.tokenSymbol,
    this.tokenLogo,
    required this.tokenDecimals,
    required this.nativePrice,
    required this.usdPrice,
    this.exchangeAddress,
    this.exchangeName,
    this.percent24h,
  });

  factory MoralisTokenPrice.fromJson(Map<String, dynamic> json) => _$MoralisTokenPriceFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisTokenPriceToJson(this);
}

@JsonSerializable()
class MoralisNativePrice {
  final String value;
  final int decimals;
  final String name;
  final String symbol;

  const MoralisNativePrice({
    required this.value,
    required this.decimals,
    required this.name,
    required this.symbol,
  });

  factory MoralisNativePrice.fromJson(Map<String, dynamic> json) => _$MoralisNativePriceFromJson(json);
  Map<String, dynamic> toJson() => _$MoralisNativePriceToJson(this);
}
