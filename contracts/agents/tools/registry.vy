# SPDX-License-Identifier: MIT
# @version ^0.3.3

# ツールレジストリ - エージェントシステムで使用可能なツールを管理するためのコントラクト

import contracts.agents.tools.interface as ToolInterface

# コントラクト変数
owner: public(address)
tools: public(HashMap[bytes32, address])  # ツールID => ツールコントラクトアドレス
tool_ids: public(DynArray[bytes32, 100])  # 登録されているすべてのツールID
tool_names: public(HashMap[String[64], bytes32])  # ツール名 => ツールID

# イベント
event ToolRegistered:
    toolId: bytes32
    toolAddress: address
    toolName: String[64]
    toolType: ToolInterface.ToolType

event ToolUnregistered:
    toolId: bytes32
    toolName: String[64]

@external
def __init__():
    """
    @notice ツールレジストリの初期化
    """
    self.owner = msg.sender

@external
def register_tool(tool_address: address) -> bytes32:
    """
    @notice ツールをレジストリに登録する
    @param tool_address 登録するツールコントラクトのアドレス
    @return 生成されたツールID
    """
    # オーナーチェック
    assert msg.sender == self.owner, "Only owner can register tools"
    
    # ツールインターフェースからツール情報を取得
    tool: ToolInterface.ToolInterface = ToolInterface.ToolInterface(tool_address)
    tool_name: String[64] = tool.name()
    
    # ツール名の重複チェック
    assert self.tool_names[tool_name] == empty(bytes32), "Tool with this name already exists"
    
    # ツールIDの生成
    tool_id: bytes32 = keccak256(convert(tool_address, bytes32))
    
    # ツールの登録
    self.tools[tool_id] = tool_address
    self.tool_ids.append(tool_id)
    self.tool_names[tool_name] = tool_id
    
    # イベントの発行
    log ToolRegistered(tool_id, tool_address, tool_name, tool.tool_type())
    
    return tool_id

@external
def unregister_tool(tool_id: bytes32):
    """
    @notice レジストリからツールを削除する
    @param tool_id 削除するツールのID
    """
    # オーナーチェック
    assert msg.sender == self.owner, "Only owner can unregister tools"
    
    # ツールの存在チェック
    tool_address: address = self.tools[tool_id]
    assert tool_address != empty(address), "Tool does not exist"
    
    # ツール名の取得
    tool: ToolInterface.ToolInterface = ToolInterface.ToolInterface(tool_address)
    tool_name: String[64] = tool.name()
    
    # ツール配列から削除（現在のVyperでは、動的配列の要素を削除する簡単な方法がないため、実際には削除せず無効化）
    # ここでは簡略化のため、ツールIDと名前のマッピングのみをクリア
    self.tools[tool_id] = empty(address)
    self.tool_names[tool_name] = empty(bytes32)
    
    # イベントの発行
    log ToolUnregistered(tool_id, tool_name)

@external
@view
def get_tool_count() -> uint256:
    """
    @notice 登録されているツールの総数を取得
    @return ツールの数
    """
    return len(self.tool_ids)

@external
@view
def get_tool_id_at(index: uint256) -> bytes32:
    """
    @notice 指定インデックスのツールIDを取得
    @param index 取得するツールのインデックス
    @return ツールID
    """
    assert index < len(self.tool_ids), "Index out of bounds"
    return self.tool_ids[index]

@external
@view
def get_tool_address(tool_id: bytes32) -> address:
    """
    @notice ツールIDからツールアドレスを取得
    @param tool_id 取得するツールのID
    @return ツールコントラクトのアドレス
    """
    return self.tools[tool_id]

@external
@view
def get_tool_id_by_name(tool_name: String[64]) -> bytes32:
    """
    @notice ツール名からツールIDを取得
    @param tool_name 取得するツールの名前
    @return ツールID
    """
    tool_id: bytes32 = self.tool_names[tool_name]
    assert tool_id != empty(bytes32), "Tool not found"
    return tool_id

@external
@view
def get_tool_info(tool_id: bytes32) -> (String[64], String[256], ToolInterface.ToolType):
    """
    @notice ツールの詳細情報を取得
    @param tool_id 情報を取得するツールのID
    @return ツール名、説明、ツールタイプ
    """
    tool_address: address = self.tools[tool_id]
    assert tool_address != empty(address), "Tool does not exist"
    
    tool: ToolInterface.ToolInterface = ToolInterface.ToolInterface(tool_address)
    return (tool.name(), tool.description(), tool.tool_type())