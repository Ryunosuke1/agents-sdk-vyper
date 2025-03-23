# SPDX-License-Identifier: MIT
# @version ^0.3.3

# OpenAITool - Chainlinkを使用してOpenAI APIに接続するツール
# このツールは、エージェントがOpenAI APIと直接対話するためのインターフェースを提供します

import contracts.agents.tools.interface as ToolInterface

interface OpenAIConnectorInterface:
    def requestOpenAICompletion(prompt: String[1024]) -> bytes32: nonpayable
    def getResponse(requestId: bytes32) -> (bool, String[1024]): view

# コントラクト変数
owner: public(address)
tool_name: public(String[64])
tool_description: public(String[256])
params_schema: public(String[512])
connector: public(OpenAIConnectorInterface)

# 実行結果の追跡
results: public(HashMap[bytes32, String[1024]])
completed: public(HashMap[bytes32, bool])
execution_count: public(uint256)

# イベント
event ToolExecuted:
    executionId: bytes32
    args: String[512]
    result: String[1024]

@external
def __init__(
    _name: String[64],
    _description: String[256],
    _connector_address: address
):
    """
    @notice OpenAI APIツールコントラクトの初期化
    @param _name ツールの名前
    @param _description ツールの説明
    @param _connector_address OpenAIコネクタコントラクトのアドレス
    """
    self.owner = msg.sender
    self.tool_name = _name
    self.tool_description = _description
    self.connector = OpenAIConnectorInterface(_connector_address)
    self.execution_count = 0
    
    # パラメータスキーマの設定（JSON形式）
    self.params_schema = """
    {
        "type": "object",
        "properties": {
            "prompt": {
                "type": "string",
                "description": "OpenAI APIに送信するプロンプト"
            },
            "options": {
                "type": "object",
                "description": "追加のAPIオプション（オプション）"
            }
        },
        "required": ["prompt"]
    }
    """

@external
@view
def name() -> String[64]:
    """
    @notice ツールの名前を取得
    @return ツールの名前
    """
    return self.tool_name

@external
@view
def description() -> String[256]:
    """
    @notice ツールの説明を取得
    @return ツールの説明
    """
    return self.tool_description

@external
@view
def tool_type() -> ToolInterface.ToolType:
    """
    @notice ツールのタイプを取得
    @return ツールのタイプ
    """
    return ToolInterface.ToolType.EXTERNAL_API

@external
@view
def params_schema() -> String[512]:
    """
    @notice ツールのパラメータスキーマを取得
    @return パラメータスキーマのJSON文字列
    """
    return self.params_schema

@external
def execute(args: String[512]) -> bytes32:
    """
    @notice ツールを実行する
    @param args ツール引数（JSON形式）
    @return 実行の結果ID
    """
    # 実行IDの生成
    execution_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(self.execution_count, bytes32),
        convert(msg.sender, bytes32)
    ))
    
    # 実行カウントの増加
    self.execution_count += 1
    
    # プロンプトの抽出（実際の実装では、JSONのパースが必要ですが、簡略化のため仮実装）
    # 注: 実際の実装では、JSONをパースして「prompt」フィールドを抽出する必要があります
    prompt: String[1024] = args
    
    # OpenAI APIリクエストを送信
    request_id: bytes32 = self.connector.requestOpenAICompletion(prompt)
    
    # リクエストIDを実行IDに関連付ける
    self.results[execution_id] = ""
    self.completed[execution_id] = False
    
    return execution_id

@external
@view
def get_result(execution_id: bytes32) -> String[1024]:
    """
    @notice 実行結果を取得する
    @param execution_id 実行ID
    @return 実行結果
    """
    return self.results[execution_id]

@external
@view
def is_execution_complete(execution_id: bytes32) -> bool:
    """
    @notice 実行が完了したかどうかをチェックする
    @param execution_id 実行ID
    @return 実行が完了した場合はTrue
    """
    return self.completed[execution_id]

@external
def update_execution_status(execution_id: bytes32):
    """
    @notice 実行ステータスを更新する
    @param execution_id 実行ID
    """
    # 更新は所有者またはOpenAIコネクタからのみ許可
    assert msg.sender == self.owner or msg.sender == self.connector.address, "Unauthorized"
    
    # リクエストIDから応答を取得
    is_complete: bool = False
    response: String[1024] = ""
    
    # リクエストIDを取得（実際の実装では、実行IDとリクエストIDのマッピングを保持する必要があります）
    # 簡略化のため、実行IDをリクエストIDとして使用
    is_complete, response = self.connector.getResponse(execution_id)
    
    if is_complete:
        # レスポンスを保存
        self.results[execution_id] = response
        self.completed[execution_id] = True
        
        # イベントの発行
        log ToolExecuted(execution_id, "", response)