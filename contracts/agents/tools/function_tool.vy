# SPDX-License-Identifier: MIT
# @version ^0.3.3

import contracts.agents.tools.interface as ToolInterface

# FunctionTool - 基本的な関数ツールの実装
# このコントラクトは、Vyperで記述された単純な関数をエージェントのツールとして提供します

owner: public(address)
tool_name: public(String[64])
tool_description: public(String[256])
params_schema: public(String[512])

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
def __init__(_name: String[64], _description: String[256], _params_schema: String[512]):
    """
    @notice ツールコントラクトの初期化
    @param _name ツールの名前
    @param _description ツールの説明
    @param _params_schema ツールのパラメータJSONスキーマ
    """
    self.owner = msg.sender
    self.tool_name = _name
    self.tool_description = _description
    self.params_schema = _params_schema
    self.execution_count = 0

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
    return ToolInterface.ToolType.FUNCTION

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
    
    # 結果を計算（このメソッドをオーバーライドして実際の機能を実装）
    result: String[1024] = self._compute_result(args)
    
    # 結果を保存
    self.results[execution_id] = result
    self.completed[execution_id] = True
    
    # イベントの発行
    log ToolExecuted(execution_id, args, result)
    
    return execution_id

@internal
def _compute_result(args: String[512]) -> String[1024]:
    """
    @notice ツールの結果を計算する
    このメソッドは派生クラスでオーバーライドする必要があります
    
    @param args ツール引数（JSON形式）
    @return 計算された結果
    """
    # このベースクラスでは、単純に引数をエコーする
    return concat("Echo: ", args)

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