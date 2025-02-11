// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CertificateRegistry {
    struct Certificate {
        string studentId;
        string id;
        string hash;
    }

    Certificate[] public certificates;

    function storeCertificateHash(string memory studentId, string memory id, string memory hash) public {
        certificates.push(Certificate(studentId, id, hash));
    }

    function getCertificateHash(string memory studentId, string memory id) public view returns (string memory) {
        for (uint i = 0; i < certificates.length; i++) {
            if (keccak256(abi.encodePacked(certificates[i].studentId)) == keccak256(abi.encodePacked(studentId)) &&
                keccak256(abi.encodePacked(certificates[i].id)) == keccak256(abi.encodePacked(id))) {
                return certificates[i].hash;
            }
        }
        return "";
    }

    function getAllCertificates() public view returns (Certificate[] memory) {
        return certificates;
    }
}
