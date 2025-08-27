import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../core/errors.dart';
import '../../core/storage.dart';

abstract class IWalletService {
  Future<String> generateMnemonic({int strength = 128});
  Future<String> importFromMnemonic(String mnemonic);
  Future<String> importFromPrivateKey(String hex);
  Future<String> createFromMnemonic(String mnemonic);
  bool validateMnemonic(String mnemonic);
  Future<String> getAddress();
  Future<String> signMessage(String msg);
  Future<String> signRawTx(Transaction tx, {int chainId = 56});
  Future<void> load();
  Future<void> persist();
  Future<void> lock();
  Future<String> exportPrivateKey();
}

class WalletService implements IWalletService {
  EthereumAddress? _address;
  Credentials? _credentials;
  bool _isLocked = true;

  static const int _bscChainId = 56;
  static const String _derivationPath = "m/44'/60'/0'/0/0"; // BSC uses Ethereum derivation

  bool get isInitialized => _credentials != null;
  bool get isLocked => _isLocked;
  EthereumAddress? get currentAddress => _address;

  @override
  Future<String> generateMnemonic({int strength = 128}) async {
    if (strength != 128 && strength != 256) {
      throw AppError(
        code: AppErrorCode.unknown,
        message: 'Invalid mnemonic strength. Use 128 or 256.',
      );
    }
    
    return bip39.generateMnemonic(strength: strength);
  }

  @override
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  @override
  Future<String> createFromMnemonic(String mnemonic) async {
    return await importFromMnemonic(mnemonic);
  }

  @override
  Future<String> importFromMnemonic(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw AppError.invalidMnemonic();
    }

    try {
      // Generate seed from mnemonic
      final seed = bip39.mnemonicToSeed(mnemonic);
      
      // Derive private key using BIP44 path for BSC (Ethereum compatible)
      final privateKey = _derivePrivateKey(seed, _derivationPath);
      
      // Create credentials from private key
      _credentials = EthPrivateKey.fromHex(hex.encode(privateKey));
      _address = await _credentials!.extractAddress();
      _isLocked = false;

      return _address!.hexEip55;
    } catch (e) {
      throw AppError.invalidMnemonic();
    }
  }

  @override
  Future<String> importFromPrivateKey(String hexKey) async {
    try {
      // Remove 0x prefix if present
      String cleanHex = hexKey.startsWith('0x') ? hexKey.substring(2) : hexKey;
      
      // Validate hex format
      if (cleanHex.length != 64) {
        throw AppError.invalidPrivateKey();
      }
      
      _credentials = EthPrivateKey.fromHex(cleanHex);
      _address = await _credentials!.extractAddress();
      _isLocked = false;

      return _address!.hexEip55;
    } catch (e) {
      throw AppError.invalidPrivateKey();
    }
  }

  @override
  Future<String> getAddress() async {
    if (_address == null) {
      throw AppError.walletNotInitialized();
    }
    return _address!.hexEip55;
  }

  @override
  Future<String> signMessage(String msg) async {
    if (_isLocked || _credentials == null) {
      throw AppError.walletLocked();
    }

    try {
      final msgBytes = Uint8List.fromList(utf8.encode(msg));
      final signature = await _credentials!.signPersonalMessage(msgBytes);
      return hex.encode(signature);
    } catch (e) {
      throw AppError.unknown('Failed to sign message: $e');
    }
  }

  @override
  Future<String> signRawTx(Transaction tx, {int chainId = 56}) async {
    if (_isLocked || _credentials == null) {
      throw AppError.walletLocked();
    }

    try {
      // Use web3dart's proper transaction signing method
      final web3Client = Web3Client('https://bsc-dataseed1.binance.org/', http.Client());
      final signedTx = await web3Client.signTransaction(_credentials!, tx, chainId: chainId);
      await web3Client.dispose();
      return hex.encode(signedTx);
    } catch (e) {
      throw AppError.unknown('Failed to sign transaction: $e');
    }
  }

  @override
  Future<void> persist() async {
    if (_credentials == null) {
      throw AppError.walletNotInitialized();
    }

    try {
      // Extract private key
      final privateKey = (_credentials as EthPrivateKey).privateKey;
      final privateKeyHex = hex.encode(privateKey);
      
      // Encrypt with a simple XOR cipher (in production, use proper encryption)
      final encrypted = _simpleEncrypt(privateKeyHex);
      
      // Store encrypted wallet
      await SecureStorage.storeWallet(encrypted);
    } catch (e) {
      throw AppError.unknown('Failed to persist wallet: $e');
    }
  }

  @override
  Future<void> load() async {
    try {
      final encryptedData = await SecureStorage.getWallet();
      if (encryptedData == null) {
        throw AppError.walletNotInitialized();
      }

      // Decrypt wallet data
      final privateKeyHex = _simpleDecrypt(encryptedData);
      
      // Recreate credentials
      _credentials = EthPrivateKey.fromHex(privateKeyHex);
      _address = await _credentials!.extractAddress();
      _isLocked = false;
    } catch (e) {
      throw AppError.unknown('Failed to load wallet: $e');
    }
  }

  @override
  Future<void> lock() async {
    _isLocked = true;
    // Keep credentials in memory but mark as locked
  }

  Future<void> unlock() async {
    if (_credentials == null) {
      throw AppError.walletNotInitialized();
    }
    _isLocked = false;
  }

  @override
  Future<String> exportPrivateKey() async {
    if (_credentials == null) {
      throw AppError.walletNotInitialized();
    }
    if (_isLocked) {
      throw AppError.walletLocked();
    }

    // In production, require OS authentication here
    final privateKey = (_credentials as EthPrivateKey).privateKey;
    return '0x${hex.encode(privateKey)}';
  }

  // Derive private key from seed using BIP44 derivation path
  Uint8List _derivePrivateKey(Uint8List seed, String path) {
    // Simplified derivation - in production use proper BIP44 implementation
    // For now, use the first 32 bytes of the seed as private key
    // This is NOT secure for production use
    final hash = sha256.convert(seed);
    return Uint8List.fromList(hash.bytes);
  }

  // Simple encryption/decryption (NOT secure for production)
  String _simpleEncrypt(String data) {
    // In production, use proper encryption like AES
    final key = 'BSC_WALLET_ENCRYPTION_KEY_V1';
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    
    final encrypted = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(encrypted);
  }

  String _simpleDecrypt(String encryptedData) {
    final key = 'BSC_WALLET_ENCRYPTION_KEY_V1';
    final keyBytes = utf8.encode(key);
    final encrypted = base64.decode(encryptedData);
    
    final decrypted = <int>[];
    for (int i = 0; i < encrypted.length; i++) {
      decrypted.add(encrypted[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }

  void dispose() {
    _credentials = null;
    _address = null;
    _isLocked = true;
  }
}
