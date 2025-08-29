import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
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
    
    final mnemonic = bip39.generateMnemonic(strength: strength);
    // Do NOT log mnemonic words (sensitive). Only log length for debugging.
    developer.log('Generated mnemonic with ${strength == 128 ? 12 : 24} words', name: 'wallet');
    return mnemonic;
  }

  @override
  bool validateMnemonic(String mnemonic) {
    final valid = bip39.validateMnemonic(mnemonic);
    developer.log('Validate mnemonic -> $valid', name: 'wallet');
    return valid;
  }

  @override
  Future<String> createFromMnemonic(String mnemonic) async {
    developer.log('Creating wallet from mnemonic (safe, no words logged)', name: 'wallet');
    return await importFromMnemonic(mnemonic);
  }

  @override
  Future<String> importFromMnemonic(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw AppError.invalidMnemonic();
    }

    try {
      developer.log('Importing from mnemonic...', name: 'wallet');
      final seed = bip39.mnemonicToSeed(mnemonic);

      // Derive using BIP32/BIP44 standard path for EVM
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath(_derivationPath);
      final pk = child.privateKey;
      if (pk == null || pk.isEmpty) {
        throw AppError.unknown('Failed to derive private key from mnemonic');
      }

      _credentials = EthPrivateKey(pk);
      _address = (_credentials as EthPrivateKey).address;
      _isLocked = false;
      developer.log('Imported from mnemonic, address: ${_address!.hexEip55}', name: 'wallet');
      return _address!.hexEip55;
    } catch (e) {
      developer.log('Failed to import from mnemonic: $e', name: 'wallet');
      throw AppError.invalidMnemonic();
    }
  }

  @override
  Future<String> importFromPrivateKey(String hexKey) async {
    try {
      developer.log('Importing from private key (masked) ...', name: 'wallet');
      // Remove 0x prefix if present
      String cleanHex = hexKey.startsWith('0x') ? hexKey.substring(2) : hexKey;
      
      // Validate hex format
      if (cleanHex.length != 64) {
        throw AppError.invalidPrivateKey();
      }
      
      _credentials = EthPrivateKey.fromHex(cleanHex);
      _address = (_credentials as EthPrivateKey).address;
      _isLocked = false;
      developer.log('Imported from private key, address: ${_address!.hexEip55}', name: 'wallet');
      return _address!.hexEip55;
    } catch (e) {
      developer.log('Failed to import from private key: $e', name: 'wallet');
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
      final signature = (_credentials as EthPrivateKey).signPersonalMessageToUint8List(msgBytes);
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
      final addr = _address?.hexEip55 ?? '(unknown)';
      developer.log('Persisting wallet for address: $addr', name: 'wallet');
      await SecureStorage.storeWallet(encrypted);
      developer.log('Wallet persisted to secure storage', name: 'wallet');
    } catch (e) {
      developer.log('Failed to persist wallet: $e', name: 'wallet');
      throw AppError.unknown('Failed to persist wallet: $e');
    }
  }

  @override
  Future<void> load() async {
    try {
      developer.log('Loading wallet from secure storage...', name: 'wallet');
      final encryptedData = await SecureStorage.getWallet();
      if (encryptedData == null) {
        throw AppError.walletNotInitialized();
      }

      // Decrypt wallet data
      final privateKeyHex = _simpleDecrypt(encryptedData);
      
      // Recreate credentials
      _credentials = EthPrivateKey.fromHex(privateKeyHex);
      _address = (_credentials as EthPrivateKey).address;
      _isLocked = false;
      developer.log('Wallet loaded, address: ${_address!.hexEip55}', name: 'wallet');
    } catch (e) {
      developer.log('Failed to load wallet: $e', name: 'wallet');
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
  Uint8List _derivePrivateKeyFromSeed(Uint8List seed, String path) {
    // Implement basic BIP44-style derivation
    // Standard BIP44 path: m/44'/60'/0'/0/0 for Ethereum
    
    // For BIP44, we need to derive step by step through the path
    // Simplified approach: use multiple HMAC rounds to simulate hierarchical derivation
    var currentKey = seed;
    
    // Parse path indices: m/44'/60'/0'/0/0
    final pathParts = ['44h', '60h', '0h', '0', '0']; // h = hardened
    
    for (int i = 0; i < pathParts.length; i++) {
      final part = pathParts[i];
      
      // Create derivation context
      final context = utf8.encode('bip44_${part}_$i');
      final hmac = Hmac(sha256, currentKey);
      final derived = hmac.convert(context);
      
      // Use derived bytes as next key
      currentKey = Uint8List.fromList(derived.bytes);
    }
    
    // Final private key derivation
    final hmac = Hmac(sha256, currentKey);
    final finalKey = hmac.convert(utf8.encode('ethereum_private_key'));
    
    // Take first 32 bytes for private key
    final privateKey = Uint8List.fromList(finalKey.bytes.take(32).toList());
    
    return privateKey;
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
