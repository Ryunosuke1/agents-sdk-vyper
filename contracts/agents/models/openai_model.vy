# SPDX-License-Identifier: MIT
# @version ^0.3.3

from vyper.interfaces import ERC20
import interfaces.ModelInterface as ModelInterface

interface OpenAIConnectorInterface:
    def requestOpenAICompletion(prompt: String[1024]) -> bytes32: nonpayable
    def getResponse(requestId: bytes32) -> (bool, String[1024]): view

# モデル設定の構造体
struct ModelSettings:
    temperature: uint256     # 0-1000 (0.0-1.0)
    max_tokens: uint256      # 最大トークン数
    top_p: uint256           # 0-1000 (0.0-1.0)
    frequency_penalty: uint256  # -200 to 200 (-2.0 to 2.0)
    presence_penalty: uint256   # -200 to 200 (-2.0 to 2.0)

# ツール呼び出し情報を追跡するための構造体
struct ToolCall:
    name: String[64]
    arguments: String[512]
    active: bool

# OpenAI APIとの通信を扱うモデル実装
owner: public(address)
model_name: public(String[64])
connector: public(OpenAIConnectorInterface)
model_settings: public(ModelSettings)

# 応答とツール呼び出しのマッピング
responses: public(HashMap[bytes32, String[1024]])
tool_calls: public(HashMap[bytes32, DynArray[ToolCall, 10]])
has_tools: public(HashMap[bytes32, bool])

# イベント
event ModelResponseReceived:
    requestId: bytes32
    response: String[1024]

event ToolCallDetected:
    requestId: bytes32
    toolName: String[64]
    arguments: String[512]

@external
def __init__(
    _model_name: String[64],
    _connector_address: address,
    _temperature: uint256,
    _max_tokens: uint256,
    _top_p: uint256,
    _frequency_penalty: uint256,
    _presence_penalty: uint256
):
    """
    @notice モデルコントラクトの初期化
    @param _model_name 使用するOpenAIモデル名（gpt-4o, gpt-3.5-turbo等）
    @param _connector_address OpenAIコネクタコントラクトのアドレス
    @param _temperature 温度設定 (0-1000 = 0.0-1.0)
    @param _max_tokens 最大トークン数
    @param _top_p 頻度設定 (0-1000 = 0.0-1.0)
    @param _frequency_penalty 頻度ペナルティ (-200 to 200 = -2.0 to 2.0)
    @param _presence_penalty 存在ペナルティ (-200 to 200 = -2.0 to 2.0)
    """
    self.owner = msg.sender
    self.model_name = _model_name
    self.connector = OpenAIConnectorInterface(_connector_address)
    
    self.model_settings = ModelSettings({
        temperature: _temperature,
        max_tokens: _max_tokens,
        top_p: _top_p,
        frequency_penalty: _frequency_penalty,
        presence_penalty: _presence_penalty
    })

@external
def get_response(
    system_instructions: String[1024],
    input: String[1024],
    tracing: ModelInterface.ModelTracing
) -> bytes32:
    """
    @notice AIモデルに対してプロンプトを送信し、レスポンスを取得する
    @param system_instructions システムプロンプト（指示）
    @param input ユーザー入力またはコンテキスト
    @param tracing トレーシングモード
    @return レスポンスID
    """
    # システム指示とユーザー入力を組み合わせた完全なプロンプトを作成
    full_prompt: String[1024] = concat(
        "System instructions: ", 
        system_instructions, 
        "\n\nUser input: ", 
        input
    )
    
    # コネクタ経由でOpenAI APIにリクエストを送信
    request_id: bytes32 = self.connector.requestOpenAICompletion(full_prompt)
    
    return request_id

@external
def get_response_text(response_id: bytes32) -> String[1024]:
    """
    @notice 特定のレスポンスIDに関連付けられた出力テキストを取得する
    @param response_id 取得するレスポンスのID
    @return レスポンスのテキスト出力
    """
    is_complete: bool = False
    response: String[1024] = ""
    
    # コネクタからレスポンスを取得
    is_complete, response = self.connector.getResponse(response_id)
    
    # レスポンスが完了していない場合は空の文字列を返す
    if not is_complete:
        return ""
    
    # レスポンスからツール呼び出しを解析（実装は簡略化）
    self._parse_tool_calls(response_id, response)
    
    # レスポンスを保存
    self.responses[response_id] = response
    
    log ModelResponseReceived(response_id, response)
    
    return response

@internal
def _parse_tool_calls(response_id: bytes32, text: String[1024]):
    """
    @notice レスポンステキストからツール呼び出しを解析する
    @param response_id レスポンスID
    @param text 解析するテキスト
    """
    # 注: 実際の実装では、正規表現や構造化されたJSONの解析が必要ですが、
    # Vyperでは複雑な文字列操作が制限されているため、簡略化された例を示します
    
    # 以下は擬似的なツール呼び出し検出の例です
    # 実際の実装では、より洗練されたパーサーが必要です
    
    # 単純な例: "tool:tool_name{arguments}"パターンを検出
    if "tool:" in text:
        # 仮のパース実装（実際はもっと複雑なロジックが必要）
        tool_name: String[64] = "detected_tool"  # 仮の実装
        tool_args: String[512] = "detected_args"  # 仮の実装
        
        # ツール呼び出し情報を追加
        tool_call: ToolCall = ToolCall({
            name: tool_name,
            arguments: tool_args,
            active: True
        })
        
        # 動的配列が現在のvyperで制限があるため簡略化
        tool_calls_array: DynArray[ToolCall, 10] = []
        tool_calls_array.append(tool_call)
        
        self.tool_calls[response_id] = tool_calls_array
        self.has_tools[response_id] = True
        
        log ToolCallDetected(response_id, tool_name, tool_args)

@external
@view
def calls_tool(response_id: bytes32, tool_name: String[64]) -> bool:
    """
    @notice レスポンスが特定のツールを呼び出すかどうかをチェックする
    @param response_id チェックするレスポンスのID
    @param tool_name チェックするツール名
    @return ツールが呼び出される場合はTrue
    """
    if not self.has_tools[response_id]:
        return False
    
    tool_calls: DynArray[ToolCall, 10] = self.tool_calls[response_id]
    
    for i in range(10):  # 最大10個までのツール呼び出しをサポート
        if i >= len(tool_calls):
            break
        
        if tool_calls[i].active and tool_calls[i].name == tool_name:
            return True
    
    return False

@external
@view
def get_tool_arguments(response_id: bytes32, tool_name: String[64]) -> String[512]:
    """
    @notice 特定のレスポンスIDに関連付けられたツール引数を取得する
    @param response_id 取得するレスポンスのID
    @param tool_name 取得するツール名
    @return ツール引数（JSON形式）
    """
    if not self.has_tools[response_id]:
        return ""
    
    tool_calls: DynArray[ToolCall, 10] = self.tool_calls[response_id]
    
    for i in range(10):  # 最大10個までのツール呼び出しをサポート
        if i >= len(tool_calls):
            break
        
        if tool_calls[i].active and tool_calls[i].name == tool_name:
            return tool_calls[i].arguments
    
    return ""