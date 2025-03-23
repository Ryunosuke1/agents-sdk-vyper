# SPDX-License-Identifier: MIT
# @version ^0.3.3

interface ChainlinkOracleInterface:
    def fulfillOracleRequest(requestId: bytes32, payment: uint256, callbackAddress: address, callbackFunctionId: bytes4, expiration: uint256, data: bytes32) -> bool: nonpayable
    def withdraw(recipient: address, amount: uint256): nonpayable
    def withdrawable() -> uint256: view