import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class BlockchainService {
  final String _rpcUrl = "https://sepolia.infura.io/v3/18f16ba782e74ff0bbde385bfd0e22c7";
  final String _wsUrl = "wss://sepolia.infura.io/ws/v3/18f16ba782e74ff0bbde385bfd0e22c7";
  final String _privateKey = "2bc35a90c32d153208819d1f186f8f6af2d489ea6cdf86797cd55d18482d90af";
  final String _contractAddress = "0x7ade7a5511bd78e2b9627e2c565341e0cbf1ccd9";
  final String _contractAbi = '''
  [
	
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "studentId",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "id",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "hash",
				"type": "string"
			}
		],
		"name": "storeCertificateHash",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"name": "certificates",
		"outputs": [
			{
				"internalType": "string",
				"name": "studentId",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "id",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "hash",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getAllCertificates",
		"outputs": [
			{
				"components": [
					{
						"internalType": "string",
						"name": "studentId",
						"type": "string"
					},
					{
						"internalType": "string",
						"name": "id",
						"type": "string"
					},
					{
						"internalType": "string",
						"name": "hash",
						"type": "string"
					}
				],
				"internalType": "struct CertificateRegistry.Certificate[]",
				"name": "",
				"type": "tuple[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "studentId",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "id",
				"type": "string"
			}
		],
		"name": "getCertificateHash",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}

]''';

  late Web3Client _client;
  late Credentials _credentials;
  late EthereumAddress _contractAddr;
  late DeployedContract _contract;
  late ContractFunction _storeHashFunction;
  late ContractFunction _getHashFunction;
  late ContractFunction _getAllCertificatesFunction;

  BlockchainService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _client = Web3Client(
        _rpcUrl,
        http.Client(),
        socketConnector: () {
          return IOWebSocketChannel.connect(_wsUrl).cast<String>();
        },
      );
      _credentials = EthPrivateKey.fromHex(_privateKey);
      _contractAddr = EthereumAddress.fromHex(_contractAddress);
      _contract = DeployedContract(
        ContractAbi.fromJson(_contractAbi, 'CertificateRegistry'),
        _contractAddr,
      );
      _storeHashFunction = _contract.function('storeCertificateHash');
      _getHashFunction = _contract.function('getCertificateHash');
      _getAllCertificatesFunction = _contract.function('getAllCertificates');
    } catch (e) {
      print('Error initializing BlockchainService: $e');
      rethrow;
    }
  }

  Future<void> storeCertificateHash(String studentId, String id, String fileHash) async {
    await _initialize(); // Ensure initialization
    try {
      final transaction = Transaction.callContract(
        contract: _contract,
        function: _storeHashFunction,
        parameters: [studentId, id, fileHash],
      );
      await _client.sendTransaction(
        _credentials,
        transaction,
        chainId: 11155111, // Ensure this is the correct chain ID for Sepolia
      );
    } catch (e) {
      print('Error storing certificate hash: $e');
      rethrow;
    }
  }

  Future<String> getCertificateHash(String studentId, String id) async {
    await _initialize(); // Ensure initialization
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getHashFunction,
        params: [studentId, id],
      );
      return result.first as String;
    } catch (e) {
      print('Error getting certificate hash: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCertificates() async {
    await _initialize(); // Ensure initialization
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getAllCertificatesFunction,
        params: [],
      );
      List<Map<String, dynamic>> certificates = [];
      for (var certificate in result[0] as List) {
        certificates.add({
          'studentId': certificate[0] as String,
          'id': certificate[1] as String,
          'hash': certificate[2] as String,
        });
      }
      return certificates;
    } catch (e) {
      print('Error getting all certificates: $e');
      rethrow;
    }
  }
}


