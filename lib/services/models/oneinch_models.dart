import 'package:json_annotation/json_annotation.dart';

part 'oneinch_models.g.dart';

@JsonSerializable()
class OneInchToken {
  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String? logoURI;
  final List<String>? tags;

  const OneInchToken({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.logoURI,
    this.tags,
  });

  factory OneInchToken.fromJson(Map<String, dynamic> json) => _$OneInchTokenFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchTokenToJson(this);
}

@JsonSerializable()
class OneInchTokensResponse {
  final Map<String, OneInchToken> tokens;

  const OneInchTokensResponse({required this.tokens});

  factory OneInchTokensResponse.fromJson(Map<String, dynamic> json) => _$OneInchTokensResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchTokensResponseToJson(this);
}

@JsonSerializable()
class OneInchQuoteResponse {
  @JsonKey(fromJson: _toStringFromDynamic)
  final String dstAmount;
  @JsonKey(fromJson: _toStringFromDynamic)
  final String gas;

  const OneInchQuoteResponse({
    required this.dstAmount,
    required this.gas,
  });

  // Convert dynamic (int/string) to string
  static String _toStringFromDynamic(dynamic value) => value.toString();

  // Backward compatibility getters for existing code
  String get toTokenAmount => dstAmount;
  String get estimatedGas => gas;
  String get fromTokenAmount => '0'; // Not provided by v6 API

  factory OneInchQuoteResponse.fromJson(Map<String, dynamic> json) => _$OneInchQuoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchQuoteResponseToJson(this);
}

@JsonSerializable()
class OneInchAllowanceResponse {
  final String allowance;

  const OneInchAllowanceResponse({required this.allowance});

  factory OneInchAllowanceResponse.fromJson(Map<String, dynamic> json) => _$OneInchAllowanceResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchAllowanceResponseToJson(this);
}

@JsonSerializable()
class OneInchSpenderResponse {
  final String address;

  const OneInchSpenderResponse({required this.address});

  factory OneInchSpenderResponse.fromJson(Map<String, dynamic> json) => _$OneInchSpenderResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchSpenderResponseToJson(this);
}

@JsonSerializable()
class OneInchTransactionData {
  final String from;
  final String to;
  final String data;
  final String value;
  final String gas;
  final String gasPrice;

  const OneInchTransactionData({
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    required this.gas,
    required this.gasPrice,
  });

  factory OneInchTransactionData.fromJson(Map<String, dynamic> json) => _$OneInchTransactionDataFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchTransactionDataToJson(this);
}

@JsonSerializable()
class OneInchSwapResponse {
  final OneInchTransactionData tx;
  final OneInchToken fromToken;
  final OneInchToken toToken;
  final String fromTokenAmount;
  final String toTokenAmount;

  const OneInchSwapResponse({
    required this.tx,
    required this.fromToken,
    required this.toToken,
    required this.fromTokenAmount,
    required this.toTokenAmount,
  });

  factory OneInchSwapResponse.fromJson(Map<String, dynamic> json) => _$OneInchSwapResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OneInchSwapResponseToJson(this);
}
