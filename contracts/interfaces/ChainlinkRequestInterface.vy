# SPDX-License-Identifier: MIT
# @version ^0.3.3

interface ChainlinkRequestInterface:
    def cancelOracleRequest(requestId: bytes32, payment: uint256, callbackFunctionId: bytes4, expiration: uint256): nonpayable
    def oracleRequest(sender: address, payment: uint256, specId: bytes32, callbackFunctionId: bytes4, nonce: uint256, dataVersion: uint256, data: Bytes[1024]) -> bytes32: nonpayable