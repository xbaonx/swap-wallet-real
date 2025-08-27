// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moralis_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoralisTokenBalance _$MoralisTokenBalanceFromJson(Map<String, dynamic> json) =>
    MoralisTokenBalance(
      tokenAddress: json['token_address'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      logo: json['logo'] as String,
      thumbnail: json['thumbnail'] as String,
      decimals: json['decimals'] as int,
      balance: json['balance'] as String,
      possibleSpam: json['possible_spam'] as bool?,
    );

Map<String, dynamic> _$MoralisTokenBalanceToJson(
        MoralisTokenBalance instance) =>
    <String, dynamic>{
      'token_address': instance.tokenAddress,
      'name': instance.name,
      'symbol': instance.symbol,
      'logo': instance.logo,
      'thumbnail': instance.thumbnail,
      'decimals': instance.decimals,
      'balance': instance.balance,
      'possible_spam': instance.possibleSpam,
    };

MoralisTokenBalancesResponse _$MoralisTokenBalancesResponseFromJson(
        Map<String, dynamic> json) =>
    MoralisTokenBalancesResponse(
      result: (json['result'] as List<dynamic>)
          .map((e) => MoralisTokenBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as String?,
    );

Map<String, dynamic> _$MoralisTokenBalancesResponseToJson(
        MoralisTokenBalancesResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'cursor': instance.cursor,
    };

MoralisTokenTransfer _$MoralisTokenTransferFromJson(
        Map<String, dynamic> json) =>
    MoralisTokenTransfer(
      transactionHash: json['transaction_hash'] as String,
      logIndex: json['log_index'] as int,
      fromAddress: json['from_address'] as String,
      toAddress: json['to_address'] as String,
      value: json['value'] as String,
      blockTimestamp: json['block_timestamp'] as String,
      blockNumber: json['block_number'] as String,
      blockHash: json['block_hash'] as String,
      tokenAddress: json['token_address'] as String,
      name: json['name'] as String?,
      symbol: json['symbol'] as String?,
      decimals: json['decimals'] as int?,
    );

Map<String, dynamic> _$MoralisTokenTransferToJson(
        MoralisTokenTransfer instance) =>
    <String, dynamic>{
      'transaction_hash': instance.transactionHash,
      'log_index': instance.logIndex,
      'from_address': instance.fromAddress,
      'to_address': instance.toAddress,
      'value': instance.value,
      'block_timestamp': instance.blockTimestamp,
      'block_number': instance.blockNumber,
      'block_hash': instance.blockHash,
      'token_address': instance.tokenAddress,
      'name': instance.name,
      'symbol': instance.symbol,
      'decimals': instance.decimals,
    };

MoralisTokenTransfersResponse _$MoralisTokenTransfersResponseFromJson(
        Map<String, dynamic> json) =>
    MoralisTokenTransfersResponse(
      result: (json['result'] as List<dynamic>)
          .map((e) => MoralisTokenTransfer.fromJson(e as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as String?,
    );

Map<String, dynamic> _$MoralisTokenTransfersResponseToJson(
        MoralisTokenTransfersResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'cursor': instance.cursor,
    };

MoralisTokenPrice _$MoralisTokenPriceFromJson(Map<String, dynamic> json) =>
    MoralisTokenPrice(
      tokenName: json['tokenName'] as String,
      tokenSymbol: json['tokenSymbol'] as String,
      tokenLogo: json['tokenLogo'] as String?,
      tokenDecimals: json['tokenDecimals'] as String,
      nativePrice: MoralisNativePrice.fromJson(
          json['nativePrice'] as Map<String, dynamic>),
      usdPrice: (json['usdPrice'] as num).toDouble(),
      exchangeAddress: json['exchangeAddress'] as String?,
      exchangeName: json['exchangeName'] as String?,
      percent24h: json['24hrPercentChange'] as String?,
    );

Map<String, dynamic> _$MoralisTokenPriceToJson(MoralisTokenPrice instance) =>
    <String, dynamic>{
      'tokenName': instance.tokenName,
      'tokenSymbol': instance.tokenSymbol,
      'tokenLogo': instance.tokenLogo,
      'tokenDecimals': instance.tokenDecimals,
      'nativePrice': instance.nativePrice,
      'usdPrice': instance.usdPrice,
      'exchangeAddress': instance.exchangeAddress,
      'exchangeName': instance.exchangeName,
      '24hrPercentChange': instance.percent24h,
    };

MoralisNativePrice _$MoralisNativePriceFromJson(Map<String, dynamic> json) =>
    MoralisNativePrice(
      value: json['value'] as String,
      decimals: json['decimals'] as int,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
    );

Map<String, dynamic> _$MoralisNativePriceToJson(MoralisNativePrice instance) =>
    <String, dynamic>{
      'value': instance.value,
      'decimals': instance.decimals,
      'name': instance.name,
      'symbol': instance.symbol,
    };
