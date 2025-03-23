# SPDX-License-Identifier: MIT
# @version ^0.3.3

interface LinkTokenInterface:
    def allowance(_owner: address, _spender: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view
    def decimals() -> uint8: view
    def decreaseApproval(_spender: address, _subtractedValue: uint256) -> bool: nonpayable
    def increaseApproval(_spender: address, _addedValue: uint256) -> bool: nonpayable
    def name() -> String[64]: view
    def symbol() -> String[32]: view
    def totalSupply() -> uint256: view
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferAndCall(_to: address, _value: uint256, _data: Bytes[1024]) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable