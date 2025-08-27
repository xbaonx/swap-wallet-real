// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oneinch_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OneInchToken _$OneInchTokenFromJson(Map<String, dynamic> json) => OneInchToken(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      decimals: json['decimals'] as int,
      logoURI: json['logoURI'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$OneInchTokenToJson(OneInchToken instance) =>
    <String, dynamic>{
      'symbol': instance.symbol,
      'name': instance.name,
      'address': instance.address,
      'decimals': instance.decimals,
      'logoURI': instance.logoURI,
      'tags': instance.tags,
    };

OneInchTokensResponse _$OneInchTokensResponseFromJson(
        Map<String, dynamic> json) =>
    OneInchTokensResponse(
      tokens: (json['tokens'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, OneInchToken.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$OneInchTokensResponseToJson(
        OneInchTokensResponse instance) =>
    <String, dynamic>{
      'tokens': instance.tokens,
    };

OneInchQuoteResponse _$OneInchQuoteResponseFromJson(
        Map<String, dynamic> json) =>
    OneInchQuoteResponse(
      dstAmount: OneInchQuoteResponse._toStringFromDynamic(json['dstAmount']),
      gas: OneInchQuoteResponse._toStringFromDynamic(json['gas']),
    );

Map<String, dynamic> _$OneInchQuoteResponseToJson(
        OneInchQuoteResponse instance) =>
    <String, dynamic>{
      'dstAmount': instance.dstAmount,
      'gas': instance.gas,
    };

OneInchAllowanceResponse _$OneInchAllowanceResponseFromJson(
        Map<String, dynamic> json) =>
    OneInchAllowanceResponse(
      allowance: json['allowance'] as String,
    );

Map<String, dynamic> _$OneInchAllowanceResponseToJson(
        OneInchAllowanceResponse instance) =>
    <String, dynamic>{
      'allowance': instance.allowance,
    };

OneInchSpenderResponse _$OneInchSpenderResponseFromJson(
        Map<String, dynamic> json) =>
    OneInchSpenderResponse(
      address: json['address'] as String,
    );

Map<String, dynamic> _$OneInchSpenderResponseToJson(
        OneInchSpenderResponse instance) =>
    <String, dynamic>{
      'address': instance.address,
    };

OneInchTransactionData _$OneInchTransactionDataFromJson(
        Map<String, dynamic> json) =>
    OneInchTransactionData(
      from: json['from'] as String,
      to: json['to'] as String,
      data: json['data'] as String,
      value: json['value'] as String,
      gas: json['gas'] as String,
      gasPrice: json['gasPrice'] as String,
    );

Map<String, dynamic> _$OneInchTransactionDataToJson(
        OneInchTransactionData instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'data': instance.data,
      'value': instance.value,
      'gas': instance.gas,
      'gasPrice': instance.gasPrice,
    };

OneInchSwapResponse _$OneInchSwapResponseFromJson(Map<String, dynamic> json) =>
    OneInchSwapResponse(
      tx: OneInchTransactionData.fromJson(json['tx'] as Map<String, dynamic>),
      fromToken:
          OneInchToken.fromJson(json['fromToken'] as Map<String, dynamic>),
      toToken: OneInchToken.fromJson(json['toToken'] as Map<String, dynamic>),
      fromTokenAmount: json['fromTokenAmount'] as String,
      toTokenAmount: json['toTokenAmount'] as String,
    );

Map<String, dynamic> _$OneInchSwapResponseToJson(
        OneInchSwapResponse instance) =>
    <String, dynamic>{
      'tx': instance.tx,
      'fromToken': instance.fromToken,
      'toToken': instance.toToken,
      'fromTokenAmount': instance.fromTokenAmount,
      'toTokenAmount': instance.toTokenAmount,
    };
